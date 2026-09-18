-- Database schema for the AI triage system (Supabase Postgres).
-- Read from the live database on 2026-09-18 through information_schema and pg_catalog.
-- Run this file on an empty database to recreate the tables, constraints, indexes, and functions.

-- calculate_email_hash() uses digest() from pgcrypto.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE requests (
    request_id varchar(255) NOT NULL,
    email_hash varchar(64) NOT NULL,
    from_email varchar(255) NOT NULL,
    subject text NOT NULL,
    body text NOT NULL,
    customer_id varchar(255),
    account_tier varchar(50),
    status varchar(50) NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    processed_at timestamptz,
    commpleted_at timestamptz,
    raw_metadata jsonb,
    CONSTRAINT requests_email_hash_key UNIQUE (email_hash),
    CONSTRAINT requests_pkey PRIMARY KEY (request_id),
    CONSTRAINT requests_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'auto_routed'::character varying, 'escalated'::character varying, 'failed'::character varying, 'completed'::character varying])::text[]))),
    CONSTRAINT valid_email CHECK (((from_email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))
);

CREATE TABLE classifications (
    id serial NOT NULL,
    request_id varchar(255) NOT NULL,
    intent varchar(100) NOT NULL,
    confidence double precision NOT NULL,
    summary text NOT NULL,
    risk_flags jsonb DEFAULT '[]'::jsonb NOT NULL,
    reasoning text,
    model_used varchar(100) NOT NULL,
    fallback_triggered boolean DEFAULT false,
    latency_ms integer NOT NULL,
    cost_usd numeric(10,6) NOT NULL,
    prompt_tokens integer,
    completion_tokens integer,
    total_tokens integer,
    validation_success boolean NOT NULL,
    validation_errors jsonb,
    created_at timestamptz DEFAULT now() NOT NULL,
    raw_response text,
    CONSTRAINT classifications_confidence_check CHECK (((confidence >= (0.0)::double precision) AND (confidence <= (1.0)::double precision))),
    CONSTRAINT classifications_cost_usd_check CHECK ((cost_usd >= (0)::numeric)),
    CONSTRAINT classifications_intent_check CHECK (((intent)::text = ANY ((ARRAY['billing_issue'::character varying, 'technical_issue'::character varying, 'refund_request'::character varying, 'legal_escalation'::character varying, 'unknown'::character varying])::text[]))),
    CONSTRAINT classifications_latency_ms_check CHECK ((latency_ms >= 0)),
    CONSTRAINT classifications_pkey PRIMARY KEY (id),
    CONSTRAINT classifications_summary_check CHECK ((length(summary) <= 500)),
    CONSTRAINT classifications_request_id_fkey FOREIGN KEY (request_id) REFERENCES requests(request_id) ON DELETE CASCADE
);

CREATE TABLE routing_decisions (
    id serial NOT NULL,
    request_id varchar(255) NOT NULL,
    decision varchar(50) NOT NULL,
    destination varchar(255) NOT NULL,
    escalation_reason varchar(100),
    escalation_priority varchar(50),
    escalation_details jsonb,
    policies_evaluated jsonb NOT NULL,
    policies_passed jsonb,
    policies_failed jsonb,
    cost_warning boolean DEFAULT false,
    latency_warning boolean DEFAULT false,
    circuit_breaker_status jsonb,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT routing_decisions_decision_check CHECK (((decision)::text = ANY ((ARRAY['auto_route'::character varying, 'escalate'::character varying])::text[]))),
    CONSTRAINT routing_decisions_escalation_priority_check CHECK (((escalation_priority)::text = ANY ((ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'critical'::character varying])::text[]))),
    CONSTRAINT routing_decisions_pkey PRIMARY KEY (id),
    CONSTRAINT routing_decisions_request_id_fkey FOREIGN KEY (request_id) REFERENCES requests(request_id) ON DELETE CASCADE
);

CREATE TABLE traces (
    trace_id varchar(255) NOT NULL,
    request_id varchar(255) NOT NULL,
    success boolean NOT NULL,
    total_latency_ms integer NOT NULL,
    total_cost_usd numeric(10,6) NOT NULL,
    steps jsonb NOT NULL,
    error_occured boolean DEFAULT false,
    error_step integer,
    error_message text,
    error_details jsonb,
    created_at timestamptz DEFAULT now() NOT NULL,
    expires_at timestamptz DEFAULT (now() + '90 days'::interval) NOT NULL,
    CONSTRAINT traces_pkey PRIMARY KEY (trace_id),
    CONSTRAINT traces_total_cost_usd_check CHECK ((total_cost_usd >= (0)::numeric)),
    CONSTRAINT traces_total_latency_ms_check CHECK ((total_latency_ms >= 0)),
    CONSTRAINT traces_request_id_fkey FOREIGN KEY (request_id) REFERENCES requests(request_id) ON DELETE CASCADE
);

CREATE TABLE failure_log (
    id serial NOT NULL,
    request_id varchar(255),
    failure_type varchar(100) NOT NULL,
    failure_details jsonb,
    component varchar(100),
    model_used varchar(100),
    cost_impact_usd numeric(10,6),
    occurred_at timestamptz DEFAULT now() NOT NULL,
    resolved boolean DEFAULT false,
    resolved_at timestamptz,
    resolution_notes text,
    CONSTRAINT failure_log_pkey PRIMARY KEY (id),
    CONSTRAINT failure_log_request_id_fkey FOREIGN KEY (request_id) REFERENCES requests(request_id) ON DELETE CASCADE
);

CREATE TABLE metrics_cache (
    id serial NOT NULL,
    window_start timestamptz NOT NULL,
    window_end timestamptz NOT NULL,
    window_type varchar(20) NOT NULL,
    total_requests integer DEFAULT 0 NOT NULL,
    auto_routed integer DEFAULT 0 NOT NULL,
    escalated integer DEFAULT 0 NOT NULL,
    failed integer DEFAULT 0 NOT NULL,
    avg_confidence double precision,
    avg_latency_ms integer,
    p50_latency_ms integer,
    p95_latency_ms integer,
    total_cost_usd numeric(10,4),
    avg_cost_usd numeric(10,6),
    intent_breakdown jsonb,
    escalation_reason jsonb,
    model_usage jsonb,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT metrics_cache_pkey PRIMARY KEY (id),
    CONSTRAINT metrics_cache_window_start_window_end_window_type_key UNIQUE (window_start, window_end, window_type),
    CONSTRAINT metrics_cache_window_type_check CHECK (((window_type)::text = ANY ((ARRAY['hour'::character varying, 'day'::character varying, 'week'::character varying])::text[])))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_requests_status ON public.requests USING btree (status);
CREATE INDEX IF NOT EXISTS idx_requests_created_at ON public.requests USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_requests_customer_id ON public.requests USING btree (customer_id);
CREATE INDEX IF NOT EXISTS idx_requests_email_hash ON public.requests USING btree (email_hash);
CREATE INDEX IF NOT EXISTS idx_requests_from_email ON public.requests USING btree (from_email);
CREATE INDEX IF NOT EXISTS idx_classifications_request_id ON public.classifications USING btree (request_id);
CREATE INDEX IF NOT EXISTS idx_classifications_intent ON public.classifications USING btree (intent);
CREATE INDEX IF NOT EXISTS idx_classifications_confidence ON public.classifications USING btree (confidence);
CREATE INDEX IF NOT EXISTS idx_classifications_created_at ON public.classifications USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_classifications_model ON public.classifications USING btree (model_used);
CREATE INDEX IF NOT EXISTS idx_classifications_risk_flags ON public.classifications USING gin (risk_flags);
CREATE INDEX IF NOT EXISTS idx_routing_decisions_request_id ON public.routing_decisions USING btree (request_id);
CREATE INDEX IF NOT EXISTS idx_routing_decisions_decision ON public.routing_decisions USING btree (decision);
CREATE INDEX IF NOT EXISTS idx_routing_decisions_escalation_reason ON public.routing_decisions USING btree (escalation_reason);
CREATE INDEX IF NOT EXISTS idx_routing_decisions_destination ON public.routing_decisions USING btree (destination);
CREATE INDEX IF NOT EXISTS idx_routing_decisions_created_at ON public.routing_decisions USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_routing_decisions_priority ON public.routing_decisions USING btree (escalation_priority);
CREATE INDEX IF NOT EXISTS idx_traces_request_id ON public.traces USING btree (request_id);
CREATE INDEX IF NOT EXISTS idx_traces_success ON public.traces USING btree (success);
CREATE INDEX IF NOT EXISTS idx_traces_error_occured ON public.traces USING btree (error_occured);
CREATE INDEX IF NOT EXISTS idx_traces_created_at ON public.traces USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_traces_expires_at ON public.traces USING btree (expires_at);

-- Functions
CREATE OR REPLACE FUNCTION public.calculate_email_hash(p_from_email character varying, p_subject text, p_body text)
 RETURNS character varying
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
    RETURN encode(digest(p_from_email || '|' || p_subject || '|' || p_body, 'sha256'), 'hex');
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_duplicate_request(p_email_hash character varying)
 RETURNS TABLE(is_duplicate boolean, existing_request_id character varying, existing_status character varying)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        TRUE AS is_duplicate,
        r.request_id,
        r.status
    FROM requests r
    WHERE r.email_hash = p_email_hash
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::VARCHAR, NULL::VARCHAR;
    END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_recent_failure_count(p_window_minutes integer DEFAULT 60)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    failure_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO failure_count
    FROM failure_log
    WHERE occurred_at > NOW() - (p_window_minutes || ' minutes')::INTERVAL
      AND failure_type IN ('malformed_llm_output', 'cost_exceeded', 'latency_exceeded', 'llm_timeout');
    
    RETURN COALESCE(failure_count, 0);
END;
$function$;


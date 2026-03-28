-- =============================================
-- FOURTHE DASHBOARD — Supabase Migration
-- Paste this entire script into SQL Editor and click Run
-- =============================================

-- 1. Organizations table (multi-tenancy root)
CREATE TABLE organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL DEFAULT 'FOURTHE',
  base_currency text DEFAULT 'AUD',
  primary_timezone text DEFAULT 'Australia/Brisbane',
  brand_primary text DEFAULT '#c8a456',
  brand_secondary text DEFAULT '#a78bfa',
  brand_logo text,
  gsheet_script_url text,
  next_job_number text DEFAULT 'FT-001',
  created_at timestamptz DEFAULT now()
);

-- 2. Profiles (extends Supabase auth.users)
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  org_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  email text,
  display_name text,
  role text DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  created_at timestamptz DEFAULT now()
);

-- 3. Clients
CREATE TABLE clients (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  org_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  contact text DEFAULT '',
  email text DEFAULT '',
  phone text DEFAULT '',
  address text DEFAULT '',
  industry text DEFAULT '',
  lifetime numeric DEFAULT 0,
  notes jsonb DEFAULT '[]',
  created_at timestamptz DEFAULT now()
);

-- 4. Projects
CREATE TABLE projects (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  org_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  client text DEFAULT '',
  job_number text DEFAULT '',
  status text DEFAULT 'planning',
  status_label text DEFAULT '',
  stage text DEFAULT 'leads',
  start_date text DEFAULT '',
  deadline text DEFAULT '',
  budget numeric DEFAULT 0,
  currency text DEFAULT 'AUD',
  budget_original numeric,
  progress integer DEFAULT 0,
  color text DEFAULT '#c8a456',
  person text DEFAULT '',
  type text DEFAULT 'Film',
  archived boolean DEFAULT false,
  archived_date text,
  phase_statuses jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- 5. Gantt Phases (child of projects)
CREATE TABLE gantt_phases (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  project_id bigint REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  key text NOT NULL,
  label text NOT NULL,
  start_date text,
  end_date text,
  color text DEFAULT '#c8a456'
);

-- 6. Budget Costs (child of projects)
CREATE TABLE budget_costs (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  project_id bigint REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  phase text DEFAULT '',
  task text DEFAULT '',
  allocated numeric DEFAULT 0,
  spent numeric DEFAULT 0,
  status text DEFAULT 'planning'
);

-- 7. Tasks
CREATE TABLE tasks (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  org_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  due text,
  priority text DEFAULT 'medium',
  project text DEFAULT '',
  done boolean DEFAULT false,
  person text DEFAULT ''
);

-- 8. Invoices
CREATE TABLE invoices (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  org_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  number text DEFAULT '',
  client text DEFAULT '',
  project text DEFAULT '',
  project_id bigint,
  description text DEFAULT '',
  amount numeric DEFAULT 0,
  paid_amount numeric DEFAULT 0,
  status text DEFAULT 'pending',
  status_label text DEFAULT 'Pending',
  due text,
  xero_id text,
  xero_number text,
  xero_status text,
  created_at timestamptz DEFAULT now()
);

-- 9. Team Members
CREATE TABLE team_members (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  org_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  preferred text DEFAULT '',
  role text DEFAULT '',
  avatar text DEFAULT '',
  color text DEFAULT '#c8a456',
  day_rate numeric DEFAULT 0,
  fee_type text DEFAULT 'day',
  phone text DEFAULT '',
  email text DEFAULT '',
  emergency_contact text DEFAULT '',
  emergency_phone text DEFAULT ''
);

-- 10. Project Crew (assignments)
CREATE TABLE project_crew (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  project_id bigint REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  person_id bigint REFERENCES team_members(id) ON DELETE CASCADE NOT NULL,
  role text DEFAULT '',
  fee_type text DEFAULT 'day',
  rate numeric DEFAULT 0,
  scheduled_days numeric DEFAULT 0,
  actual_days numeric DEFAULT 0
);

-- 11. Bills
CREATE TABLE bills (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  org_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  from_name text DEFAULT '',
  description text DEFAULT '',
  amount numeric DEFAULT 0,
  paid_amount numeric DEFAULT 0,
  reference text DEFAULT '',
  date_received text,
  due_date text,
  project text DEFAULT '',
  status text DEFAULT 'unpaid',
  paid_date text,
  created_at timestamptz DEFAULT now()
);

-- 12. Integrations
CREATE TABLE integrations (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  org_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  description text DEFAULT '',
  icon text DEFAULT '',
  color text DEFAULT '',
  status text DEFAULT 'off'
);

-- 13. Custom Industries
CREATE TABLE custom_industries (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  org_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL
);

-- 14. Access Requests
CREATE TABLE access_requests (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  org_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  first_name text DEFAULT '',
  last_name text DEFAULT '',
  email text NOT NULL,
  reason text DEFAULT '',
  status text DEFAULT 'pending',
  requested_at timestamptz DEFAULT now()
);

-- =============================================
-- HELPER FUNCTION: get current user's org_id
-- =============================================
CREATE OR REPLACE FUNCTION public.get_user_org_id()
RETURNS uuid AS $$
  SELECT org_id FROM public.profiles WHERE id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================

-- Enable RLS on all tables
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE gantt_phases ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_crew ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_industries ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_requests ENABLE ROW LEVEL SECURITY;

-- Organizations: users can read/update their own org
CREATE POLICY "org_select" ON organizations FOR SELECT USING (id = public.get_user_org_id());
CREATE POLICY "org_update" ON organizations FOR UPDATE USING (id = public.get_user_org_id());

-- Profiles: users can read all profiles in their org, update their own
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (id = auth.uid());

-- Macro for org-scoped tables: SELECT, INSERT, UPDATE, DELETE
-- Clients
CREATE POLICY "clients_select" ON clients FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY "clients_insert" ON clients FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY "clients_update" ON clients FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY "clients_delete" ON clients FOR DELETE USING (org_id = public.get_user_org_id());

-- Projects
CREATE POLICY "projects_select" ON projects FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY "projects_insert" ON projects FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY "projects_update" ON projects FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY "projects_delete" ON projects FOR DELETE USING (org_id = public.get_user_org_id());

-- Gantt Phases (via project)
CREATE POLICY "gantt_select" ON gantt_phases FOR SELECT USING (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = gantt_phases.project_id AND projects.org_id = public.get_user_org_id())
);
CREATE POLICY "gantt_insert" ON gantt_phases FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = gantt_phases.project_id AND projects.org_id = public.get_user_org_id())
);
CREATE POLICY "gantt_update" ON gantt_phases FOR UPDATE USING (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = gantt_phases.project_id AND projects.org_id = public.get_user_org_id())
);
CREATE POLICY "gantt_delete" ON gantt_phases FOR DELETE USING (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = gantt_phases.project_id AND projects.org_id = public.get_user_org_id())
);

-- Budget Costs (via project)
CREATE POLICY "costs_select" ON budget_costs FOR SELECT USING (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = budget_costs.project_id AND projects.org_id = public.get_user_org_id())
);
CREATE POLICY "costs_insert" ON budget_costs FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = budget_costs.project_id AND projects.org_id = public.get_user_org_id())
);
CREATE POLICY "costs_update" ON budget_costs FOR UPDATE USING (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = budget_costs.project_id AND projects.org_id = public.get_user_org_id())
);
CREATE POLICY "costs_delete" ON budget_costs FOR DELETE USING (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = budget_costs.project_id AND projects.org_id = public.get_user_org_id())
);

-- Tasks
CREATE POLICY "tasks_select" ON tasks FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY "tasks_insert" ON tasks FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY "tasks_update" ON tasks FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY "tasks_delete" ON tasks FOR DELETE USING (org_id = public.get_user_org_id());

-- Invoices
CREATE POLICY "invoices_select" ON invoices FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY "invoices_insert" ON invoices FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY "invoices_update" ON invoices FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY "invoices_delete" ON invoices FOR DELETE USING (org_id = public.get_user_org_id());

-- Team Members
CREATE POLICY "team_select" ON team_members FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY "team_insert" ON team_members FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY "team_update" ON team_members FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY "team_delete" ON team_members FOR DELETE USING (org_id = public.get_user_org_id());

-- Project Crew (via project)
CREATE POLICY "crew_select" ON project_crew FOR SELECT USING (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = project_crew.project_id AND projects.org_id = public.get_user_org_id())
);
CREATE POLICY "crew_insert" ON project_crew FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = project_crew.project_id AND projects.org_id = public.get_user_org_id())
);
CREATE POLICY "crew_update" ON project_crew FOR UPDATE USING (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = project_crew.project_id AND projects.org_id = public.get_user_org_id())
);
CREATE POLICY "crew_delete" ON project_crew FOR DELETE USING (
  EXISTS (SELECT 1 FROM projects WHERE projects.id = project_crew.project_id AND projects.org_id = public.get_user_org_id())
);

-- Bills
CREATE POLICY "bills_select" ON bills FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY "bills_insert" ON bills FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY "bills_update" ON bills FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY "bills_delete" ON bills FOR DELETE USING (org_id = public.get_user_org_id());

-- Integrations
CREATE POLICY "integrations_select" ON integrations FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY "integrations_insert" ON integrations FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY "integrations_update" ON integrations FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY "integrations_delete" ON integrations FOR DELETE USING (org_id = public.get_user_org_id());

-- Custom Industries
CREATE POLICY "industries_select" ON custom_industries FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY "industries_insert" ON custom_industries FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY "industries_update" ON custom_industries FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY "industries_delete" ON custom_industries FOR DELETE USING (org_id = public.get_user_org_id());

-- Access Requests (readable by org members, insertable by anyone)
CREATE POLICY "requests_select" ON access_requests FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY "requests_insert" ON access_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "requests_update" ON access_requests FOR UPDATE USING (org_id = public.get_user_org_id());

-- =============================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- =============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  default_org_id uuid;
BEGIN
  -- Get the first (default) organization
  SELECT id INTO default_org_id FROM public.organizations LIMIT 1;

  -- If no org exists yet, create one
  IF default_org_id IS NULL THEN
    INSERT INTO public.organizations (name) VALUES ('FOURTHE') RETURNING id INTO default_org_id;
  END IF;

  INSERT INTO public.profiles (id, org_id, email, display_name, role)
  VALUES (
    NEW.id,
    default_org_id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    CASE WHEN (SELECT count(*) FROM public.profiles WHERE org_id = default_org_id) = 0 THEN 'admin' ELSE 'member' END
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: auto-create profile when a new user signs up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================
-- ENABLE REALTIME
-- =============================================
ALTER PUBLICATION supabase_realtime ADD TABLE projects;
ALTER PUBLICATION supabase_realtime ADD TABLE clients;
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE invoices;
ALTER PUBLICATION supabase_realtime ADD TABLE team_members;
ALTER PUBLICATION supabase_realtime ADD TABLE project_crew;
ALTER PUBLICATION supabase_realtime ADD TABLE bills;
ALTER PUBLICATION supabase_realtime ADD TABLE gantt_phases;
ALTER PUBLICATION supabase_realtime ADD TABLE budget_costs;
ALTER PUBLICATION supabase_realtime ADD TABLE integrations;

-- =============================================
-- DONE! Now create your first user account via
-- your dashboard login screen.
-- =============================================

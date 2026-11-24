-- =====================================================================
-- MATRIX V6.0 — PLATAFORMA MULTI-PROJETO — ETAPA A (criar e preencher)
-- Onde rodar: Supabase → SQL Editor → New query → cole tudo → Run
--
-- O QUE ESTA ETAPA FAZ (só acrescenta — nada é apagado ou alterado):
--   1) guarda uma CÓPIA DE BACKUP das tabelas atuais (backup_v6_*);
--   2) cria as tabelas da plataforma: plataforma_projetos, projeto_membros, projeto_config;
--   3) cadastra o MATRIX como primeiro projeto (mesmo id de hoje: projetomatrixenergisa);
--   4) torna membros do MATRIX todas as contas liberadas hoje, com o mesmo papel;
--   5) copia as permissões atuais do MATRIX para a configuração do projeto.
--
-- NÃO MEXE em: dados do MATRIX (projeto_estado / projeto_versoes), logins e senhas
-- (auth.users), perfis, config_app, super_usuario. Pode rodar mais de uma vez.
-- Depois desta etapa a V5.2 publicada continua funcionando normalmente.
-- =====================================================================

-- 0) Pré-requisitos da V5.2 (só cria se faltar)
create table if not exists public.super_usuario (
  user_id uuid primary key references auth.users(id) on delete cascade,
  criado_em timestamptz not null default now());
create or replace function public.eh_super() returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from super_usuario where user_id = auth.uid()) $$;
create or replace function public.eh_super_id(uid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from super_usuario where user_id = uid) $$;

-- 1) Backup das tabelas atuais (cópia fiel; criada só na primeira execução)
create table if not exists public.backup_v6_projeto_estado as table public.projeto_estado;
create table if not exists public.backup_v6_perfis         as table public.perfis;
create table if not exists public.backup_v6_config_app     as table public.config_app;
create table if not exists public.backup_v6_super_usuario  as table public.super_usuario;
-- as cópias ficam fechadas: sem regra de acesso, ninguém lê pelo aplicativo
alter table public.backup_v6_projeto_estado enable row level security;
alter table public.backup_v6_perfis         enable row level security;
alter table public.backup_v6_config_app     enable row level security;
alter table public.backup_v6_super_usuario  enable row level security;

-- 2) Tabelas da plataforma
create table if not exists public.plataforma_projetos (
  id          text primary key check (id ~ '^[a-z0-9][a-z0-9-]{1,48}$'),
  nome        text not null,
  descricao   text not null default '',
  logo        text not null default '',          -- imagem (data URL) ou endereço
  cor         text not null default '#1F6FB5',   -- cor de destaque do projeto
  versao      text not null default '1.0',       -- versão em uso (1.0, 2.0, ...)
  html        text not null default '',          -- arquivo próprio da versão; vazio = o arquivo principal
  modulos     jsonb not null default '{}'::jsonb, -- abas e funções: {"usinas": false, ...}
  ativo       boolean not null default true,
  ordem       integer not null default 100,
  criado_por  text,
  criado_em   timestamptz not null default now(),
  updated_at  timestamptz not null default now());

create table if not exists public.projeto_membros (
  projeto_id  text not null references public.plataforma_projetos(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  papel       text not null default 'usuario' check (papel in ('admin','usuario','leitor')),
  ativo       boolean not null default true,
  criado_em   timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (projeto_id, user_id));
create index if not exists projeto_membros_user on public.projeto_membros(user_id);

create table if not exists public.projeto_config (
  projeto_id  text not null references public.plataforma_projetos(id) on delete cascade,
  chave       text not null,
  valor       jsonb not null default '{}'::jsonb,
  updated_by  text,
  updated_at  timestamptz not null default now(),
  primary key (projeto_id, chave));

-- 3) MATRIX como primeiro projeto (não altera o cadastro se já existir)
insert into public.plataforma_projetos(id, nome, descricao, cor, versao, ordem, criado_por)
values ('projetomatrixenergisa', 'PROJETO MATRIX ENERGISA UFV 2026',
        'Gestão Técnica da Migração de UFVs — Matrix → Reenergisa', '#1F6FB5', '6.0', 1, 'migração V6.0')
on conflict (id) do nothing;

-- 4) Contas liberadas hoje viram membros do MATRIX com o mesmo papel
insert into public.projeto_membros(projeto_id, user_id, papel, ativo)
select 'projetomatrixenergisa', p.user_id, case when p.papel = 'admin' then 'admin' else 'usuario' end, true
from public.perfis p
where p.ativo
on conflict (projeto_id, user_id) do nothing;

-- 5) Permissões do usuário do MATRIX copiadas para a configuração do projeto
insert into public.projeto_config(projeto_id, chave, valor, updated_by)
select 'projetomatrixenergisa', 'permissoes', c.valor, 'migração V6.0'
from public.config_app c where c.id = 'permissoes'
on conflict (projeto_id, chave) do nothing;

-- 6) Funções de acesso por projeto (usadas na etapa B)
create or replace function public.eh_membro(p text) returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from projeto_membros m
                join plataforma_projetos j on j.id = m.projeto_id
                join perfis f on f.user_id = m.user_id
                where m.projeto_id = p and m.user_id = auth.uid() and m.ativo and j.ativo and f.ativo) $$;
create or replace function public.papel_projeto(p text) returns text language sql stable security definer set search_path = public as $$
  select case when eh_super() then 'super'
              when eh_membro(p) then (select papel from projeto_membros where projeto_id = p and user_id = auth.uid())
              else null end $$;
create or replace function public.eh_admin_projeto(p text) returns boolean language sql stable security definer set search_path = public as $$
  select eh_super() or (eh_membro(p) and exists(select 1 from projeto_membros where projeto_id = p and user_id = auth.uid() and papel = 'admin')) $$;
create or replace function public.eh_admin_algum() returns boolean language sql stable security definer set search_path = public as $$
  select eh_super() or exists(select 1 from projeto_membros m join perfis f on f.user_id = m.user_id
                              where m.user_id = auth.uid() and m.papel = 'admin' and m.ativo and f.ativo) $$;
create or replace function public.pode_editar_projeto(p text) returns boolean language sql stable security definer set search_path = public as $$
  select eh_admin_projeto(p) or (
    eh_membro(p)
    and exists(select 1 from projeto_membros where projeto_id = p and user_id = auth.uid() and papel = 'usuario')
    and exists(select 1 from projeto_config c, jsonb_each_text(c.valor) e
               where c.projeto_id = p and c.chave = 'permissoes' and e.key <> 'exportar' and e.value = 'true')) $$;
-- libera a conta de quem recebeu acesso a um projeto (superusuário ou administrador de projeto)
create or replace function public.liberar_conta(uid uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  if not eh_admin_algum() then raise exception 'sem permissão'; end if;
  if eh_super_id(uid) and not eh_super() then raise exception 'sem permissão'; end if;
  update perfis set ativo = true where user_id = uid and not ativo;
end $$;
revoke all on function public.liberar_conta(uuid) from public, anon;
grant execute on function public.liberar_conta(uuid) to authenticated;

-- 7) Regras das tabelas novas
alter table public.plataforma_projetos enable row level security;
alter table public.projeto_membros     enable row level security;
alter table public.projeto_config      enable row level security;
do $$ begin
  -- projetos: o superusuário vê todos; cada pessoa vê os projetos ativos em que é membro
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plataforma_projetos' and policyname='plat_ler') then
    create policy plat_ler on public.plataforma_projetos for select to authenticated using (eh_super() or (ativo and eh_membro(id))); end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plataforma_projetos' and policyname='plat_super_ins') then
    create policy plat_super_ins on public.plataforma_projetos for insert to authenticated with check (eh_super()); end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plataforma_projetos' and policyname='plat_super_upd') then
    create policy plat_super_upd on public.plataforma_projetos for update to authenticated using (eh_super()) with check (eh_super()); end if;
  -- membros: cada um vê os próprios vínculos; superusuário e administrador do projeto gerenciam
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='projeto_membros' and policyname='memb_ler') then
    create policy memb_ler on public.projeto_membros for select to authenticated using (user_id = auth.uid() or eh_admin_projeto(projeto_id)); end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='projeto_membros' and policyname='memb_ins') then
    create policy memb_ins on public.projeto_membros for insert to authenticated
      with check (eh_super() or (eh_admin_projeto(projeto_id) and not eh_super_id(user_id))); end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='projeto_membros' and policyname='memb_upd') then
    create policy memb_upd on public.projeto_membros for update to authenticated
      using (eh_super() or (eh_admin_projeto(projeto_id) and not eh_super_id(user_id)))
      with check (eh_super() or (eh_admin_projeto(projeto_id) and not eh_super_id(user_id))); end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='projeto_membros' and policyname='memb_del') then
    create policy memb_del on public.projeto_membros for delete to authenticated
      using (eh_super() or (eh_admin_projeto(projeto_id) and not eh_super_id(user_id))); end if;
  -- configuração de cada projeto (permissões etc.)
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='projeto_config' and policyname='pcfg_ler') then
    create policy pcfg_ler on public.projeto_config for select to authenticated using (eh_super() or eh_membro(projeto_id)); end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='projeto_config' and policyname='pcfg_ins') then
    create policy pcfg_ins on public.projeto_config for insert to authenticated with check (eh_admin_projeto(projeto_id)); end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='projeto_config' and policyname='pcfg_upd') then
    create policy pcfg_upd on public.projeto_config for update to authenticated using (eh_admin_projeto(projeto_id)) with check (eh_admin_projeto(projeto_id)); end if;
  -- administradores de projeto enxergam a lista de contas para liberar pessoas
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='perfis' and policyname='perfis_ler_admproj') then
    create policy perfis_ler_admproj on public.perfis for select to authenticated using (eh_admin_algum()); end if;
end $$;

-- 8) Conferência (somente leitura)
select
  (select count(*) from auth.users)                                   as contas_de_login,
  (select count(*) from public.plataforma_projetos)                   as projetos,
  (select count(*) from public.projeto_membros where projeto_id='projetomatrixenergisa') as membros_matrix,
  (select count(*) from public.projeto_config)                        as configuracoes,
  (select count(*) from public.backup_v6_projeto_estado)              as backup_projetos,
  (select rev from public.projeto_estado where id='projetomatrixenergisa')  as rev_matrix_atual,
  (select rev from public.backup_v6_projeto_estado where id='projetomatrixenergisa') as rev_matrix_backup;

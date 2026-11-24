-- =====================================================================
-- MATRIX V6.1 — ajustes de acesso (rode depois do SQL da V6.0)
-- Não altera dados de nenhum projeto, logins ou senhas. Pode rodar mais de uma vez.
--
-- 1) Administradores deixam de VER a conta do superusuário (lista de usuários) —
--    e continuam sem poder alterá-la. Só o superusuário vê e altera a própria conta.
-- 2) A configuração da tela de login (aparência) passa a ser exclusiva do superusuário.
-- 3) O MATRIX passa a constar como V6.1 no cadastro da plataforma.
-- =====================================================================

-- 1) lista de contas: o superusuário fica oculto para os demais
drop policy if exists perfis_ler on public.perfis;
create policy perfis_ler on public.perfis for select to authenticated
  using (user_id = auth.uid() or (eh_admin() and (eh_super() or not eh_super_id(user_id))));
drop policy if exists perfis_ler_admproj on public.perfis;
create policy perfis_ler_admproj on public.perfis for select to authenticated
  using (eh_admin_algum() and (eh_super() or not eh_super_id(user_id)));
-- (a alteração da conta do superusuário por administradores já é bloqueada pela regra perfis_admin)

-- 2) tela de login: somente o superusuário grava a aparência
drop policy if exists config_admin_ins on public.config_app;
create policy config_admin_ins on public.config_app for insert to authenticated
  with check (eh_admin() and (id <> 'aparencia' or eh_super()));
drop policy if exists config_admin_upd on public.config_app;
create policy config_admin_upd on public.config_app for update to authenticated
  using (eh_admin() and (id <> 'aparencia' or eh_super()))
  with check (eh_admin() and (id <> 'aparencia' or eh_super()));

-- 3) versão do MATRIX no cadastro da plataforma
update public.plataforma_projetos set versao = '6.1', updated_at = now()
  where id = 'projetomatrixenergisa' and versao in ('6.0', '');

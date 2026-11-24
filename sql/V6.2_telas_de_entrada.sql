-- =====================================================================
-- MATRIX V6.2 — telas de entrada (rode depois do SQL da V6.1)
-- Não altera dados de nenhum projeto, logins ou senhas. Pode rodar mais de uma vez.
-- A tela de login (config_app 'aparencia') e a tela de escolha de projeto
-- (config_app 'tela_selecao') passam a ser gravadas somente pelo superusuário.
-- =====================================================================
drop policy if exists config_admin_ins on public.config_app;
create policy config_admin_ins on public.config_app for insert to authenticated
  with check (eh_admin() and (id not in ('aparencia','tela_selecao') or eh_super()));
drop policy if exists config_admin_upd on public.config_app;
create policy config_admin_upd on public.config_app for update to authenticated
  using (eh_admin() and (id not in ('aparencia','tela_selecao') or eh_super()))
  with check (eh_admin() and (id not in ('aparencia','tela_selecao') or eh_super()));
update public.plataforma_projetos set versao = '6.2', updated_at = now()
  where id = 'projetomatrixenergisa' and versao in ('6.0', '6.1', '');

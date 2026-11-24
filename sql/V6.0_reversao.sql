-- =====================================================================
-- MATRIX V6.0 — REVERSÃO (volta as regras de acesso da V5.2)
-- Use só se precisar voltar para a V5.2. Não apaga nenhum dado: as tabelas da
-- plataforma e os backups continuam no banco (sem efeito para a V5.2).
-- Depois de rodar, republique a V5.2 no GitHub (index.html apontando para ela).
-- =====================================================================
drop policy if exists proj6_ler     on public.projeto_estado;
drop policy if exists proj6_criar   on public.projeto_estado;
drop policy if exists proj6_alterar on public.projeto_estado;
drop policy if exists vers6_ler     on public.projeto_versoes;
drop policy if exists projeto_ler     on public.projeto_estado;
drop policy if exists projeto_criar   on public.projeto_estado;
drop policy if exists projeto_alterar on public.projeto_estado;
drop policy if exists versoes_ler     on public.projeto_versoes;
create policy projeto_ler     on public.projeto_estado  for select to authenticated using (eh_ativo());
create policy projeto_criar   on public.projeto_estado  for insert to authenticated with check (eh_admin());
create policy projeto_alterar on public.projeto_estado  for update to authenticated using (pode_editar()) with check (pode_editar());
create policy versoes_ler     on public.projeto_versoes for select to authenticated using (eh_ativo());

-- Restaurar os DADOS do MATRIX a partir do backup da V6 (só se for realmente necessário;
-- tire o comentário das linhas abaixo). Isso substitui o estado atual pelo salvo antes da migração.
-- update public.projeto_estado p set state = b.state, rev = b.rev, updated_by = b.updated_by, updated_at = now()
--   from public.backup_v6_projeto_estado b where b.id = p.id and p.id = 'projetomatrixenergisa';

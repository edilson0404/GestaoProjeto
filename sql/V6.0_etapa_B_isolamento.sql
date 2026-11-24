-- =====================================================================
-- MATRIX V6.0 — ETAPA B (isolamento por projeto nas regras do banco)
-- Rode DEPOIS da etapa A, no mesmo momento em que publicar a V6.0 no GitHub.
--
-- O que muda: as regras de leitura e gravação dos projetos passam a exigir que a
-- conta seja MEMBRO daquele projeto (o superusuário vê todos). Nenhum dado é
-- alterado. Para voltar atrás: rode o SQL de reversão (V6_reversao.sql).
-- =====================================================================

-- dados dos projetos
drop policy if exists projeto_ler     on public.projeto_estado;
drop policy if exists projeto_criar   on public.projeto_estado;
drop policy if exists projeto_alterar on public.projeto_estado;
drop policy if exists proj6_ler       on public.projeto_estado;
drop policy if exists proj6_criar     on public.projeto_estado;
drop policy if exists proj6_alterar   on public.projeto_estado;
create policy proj6_ler     on public.projeto_estado for select to authenticated using (eh_super() or eh_membro(id));
create policy proj6_criar   on public.projeto_estado for insert to authenticated with check (eh_admin_projeto(id));
create policy proj6_alterar on public.projeto_estado for update to authenticated using (pode_editar_projeto(id)) with check (pode_editar_projeto(id));

-- histórico de versões
drop policy if exists versoes_ler  on public.projeto_versoes;
drop policy if exists vers6_ler    on public.projeto_versoes;
create policy vers6_ler on public.projeto_versoes for select to authenticated using (eh_super() or eh_membro(projeto_id));

-- conferência: quem continua vendo o MATRIX
select (select count(*) from public.projeto_membros where projeto_id = 'projetomatrixenergisa' and ativo) as membros_ativos_matrix,
       (select count(*) from pg_policies where schemaname = 'public' and tablename in ('projeto_estado','projeto_versoes')) as regras_projetos;

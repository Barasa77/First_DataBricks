import { useMemo } from 'react';
import {
  useAnalyticsQuery,
  Alert,
  AlertDescription,
  AlertTitle,
  Badge,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyTitle,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@databricks/appkit-ui/react';
import {
  HOJE,
  NOME_CAUSA,
  fmtIndice,
  fmtInteiro,
  fmtPercentual,
  fmtReais,
  num,
  useScoreEstouro,
  verdadeiro,
} from '../lib/dados';

function Kpi({ titulo, valor, detalhe, carregando }: { titulo: string; valor: string; detalhe: string; carregando: boolean }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardDescription>{titulo}</CardDescription>
        {carregando ? <Skeleton className="h-8 w-24" /> : <CardTitle className="text-3xl tabular-nums">{valor}</CardTitle>}
      </CardHeader>
      <CardContent className="text-xs text-muted-foreground">{detalhe}</CardContent>
    </Card>
  );
}

function Situacao({ valor }: { valor: string }) {
  if (valor === 'crítico') return <Badge className="bg-destructive text-destructive-foreground">crítico</Badge>;
  if (valor === 'atenção') return <Badge className="bg-warning text-warning-foreground">atenção</Badge>;
  return <Badge variant="outline">{valor}</Badge>;
}

export function ProjetosRiscoPage() {
  const semParametros = useMemo(() => ({}), []);
  const kpis = useAnalyticsQuery('kpis', semParametros);
  const projetos = useAnalyticsQuery('projetos_risco', semParametros);
  const score = useScoreEstouro();

  const k = kpis.data?.[0];
  const probPorProjeto = useMemo(
    () => new Map(score.linhas.map((l) => [l.projeto_id, num(l.prob_estouro_30d)])),
    [score.linhas],
  );
  const altoRisco = score.linhas.filter((l) => l.faixa_risco === 'alto').length;

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto">
      <div>
        <h2 className="text-2xl font-semibold">Quais projetos estão atrasados, e quanto vai custar?</h2>
        <p className="text-sm text-muted-foreground">
          Projetos em andamento na fotografia de {HOJE} · gold.projeto_situacao_atual, recalculada toda segunda às 6h.
          SPI ou CPI &lt; 0,9 = atenção, &lt; 0,8 = crítico.
        </p>
      </div>

      {kpis.error && (
        <Alert variant="destructive">
          <AlertTitle>Não foi possível ler os KPIs</AlertTitle>
          <AlertDescription>{kpis.error}</AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Kpi
          titulo="Projetos em risco"
          valor={k ? `${fmtInteiro(k.em_risco)} de ${fmtInteiro(k.projetos_em_andamento)}` : '—'}
          detalhe={k ? `${fmtInteiro(k.criticos)} críticos · ${fmtInteiro(k.melancias)} melancias (farol verde, SPI < 0,9)` : 'atenção + crítico'}
          carregando={kpis.loading}
        />
        <Kpi
          titulo="Estouro previsto"
          valor={k ? fmtReais(k.estouro_previsto) : '—'}
          detalhe="EAC − orçamento, quando positivo"
          carregando={kpis.loading}
        />
        <Kpi
          titulo="Carteira em andamento"
          valor={k ? fmtReais(k.carteira) : '—'}
          detalhe="soma do valor dos contratos"
          carregando={kpis.loading}
        />
        <Kpi
          titulo="Alto risco em 30 dias"
          valor={score.disponivel ? fmtInteiro(altoRisco) : '—'}
          detalhe={score.disponivel ? 'modelo de estouro (faixa alto)' : 'modelo ainda não publicado (gold.score_estouro_30d)'}
          carregando={score.carregando}
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Projetos em andamento, do pior para o melhor</CardTitle>
          <CardDescription>
            O farol do gerente ao lado do farol pelo número. A causa é a mais frequente no status semanal dos últimos 90 dias.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {projetos.loading && (
            <div className="space-y-2">
              {Array.from({ length: 6 }, (_, i) => (
                <Skeleton key={i} className="h-8 w-full" />
              ))}
            </div>
          )}
          {projetos.error && (
            <Alert variant="destructive">
              <AlertTitle>Não foi possível ler os projetos</AlertTitle>
              <AlertDescription>{projetos.error}</AlertDescription>
            </Alert>
          )}
          {projetos.data && projetos.data.length === 0 && (
            <Empty>
              <EmptyHeader>
                <EmptyTitle>Nenhum projeto em andamento</EmptyTitle>
                <EmptyDescription>Confira se o job vertice_farol rodou na última segunda.</EmptyDescription>
              </EmptyHeader>
            </Empty>
          )}
          {projetos.data && projetos.data.length > 0 && (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Projeto</TableHead>
                  <TableHead>Situação</TableHead>
                  <TableHead className="text-right">SPI</TableHead>
                  <TableHead className="text-right">CPI</TableHead>
                  <TableHead className="text-right">Estouro</TableHead>
                  <TableHead className="text-right">Atraso (dias)</TableHead>
                  <TableHead>Farol do gerente</TableHead>
                  <TableHead>Farol pelo número</TableHead>
                  <TableHead>Causa (90 dias)</TableHead>
                  <TableHead className="text-right">P(estouro)</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {projetos.data.map((p) => {
                  const prob = probPorProjeto.get(p.projeto_id);
                  return (
                    <TableRow key={p.projeto_id}>
                      <TableCell>
                        <div className="font-medium">{p.projeto_id}</div>
                        <div className="text-xs text-muted-foreground">{p.cliente}</div>
                      </TableCell>
                      <TableCell>
                        <Situacao valor={p.situacao} />
                      </TableCell>
                      <TableCell className="text-right tabular-nums">{fmtIndice(p.spi)}</TableCell>
                      <TableCell className="text-right tabular-nums">{fmtIndice(p.cpi)}</TableCell>
                      <TableCell className="text-right tabular-nums">{fmtReais(p.estouro_previsto)}</TableCell>
                      <TableCell className="text-right tabular-nums">{fmtInteiro(p.atraso_projetado_dias)}</TableCell>
                      <TableCell>
                        {p.farol_do_gerente}
                        {verdadeiro(p.melancia) && (
                          <span className="ml-1" title="melancia: verde por fora, vermelho por dentro">
                            🍉
                          </span>
                        )}
                      </TableCell>
                      <TableCell>{p.farol_calculado}</TableCell>
                      <TableCell>
                        {p.causa_principal ? (
                          <span>
                            {NOME_CAUSA[p.causa_principal] ?? p.causa_principal}{' '}
                            <span className="text-xs text-muted-foreground">({fmtInteiro(p.semanas_causa_principal)} sem.)</span>
                          </span>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        {prob === undefined ? '—' : fmtPercentual(prob)}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

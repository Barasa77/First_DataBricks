import { useMemo, useState } from 'react';
import {
  useAnalyticsQuery,
  Alert,
  AlertDescription,
  AlertTitle,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyTitle,
  Input,
  Label,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
} from '@databricks/appkit-ui/react';
import { HOJE, NOME_CAUSA, fmtDecimal1, fmtIndice, fmtInteiro, fmtPercentual, fmtReaisInteiro, num } from '../lib/dados';

const SEMANAS_NO_MES = 4;

function Resultado({ titulo, valor, detalhe, destaque }: { titulo: string; valor: string; detalhe: string; destaque?: 'bom' | 'ruim' }) {
  const cor = destaque === 'bom' ? 'text-success' : destaque === 'ruim' ? 'text-destructive' : '';
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardDescription>{titulo}</CardDescription>
        <CardTitle className={`text-2xl tabular-nums ${cor}`}>{valor}</CardTitle>
      </CardHeader>
      <CardContent className="text-xs text-muted-foreground">{detalhe}</CardContent>
    </Card>
  );
}

export function SimuladorPage() {
  const semParametros = useMemo(() => ({}), []);
  const pessoas = useAnalyticsQuery('pessoas_ociosas', semParametros);
  const projetos = useAnalyticsQuery('projetos_risco', semParametros);

  const [pessoaId, setPessoaId] = useState<string>('');
  const [destinoId, setDestinoId] = useState<string>('');
  const [horasOnboarding, setHorasOnboarding] = useState<string>('40');

  const pessoa = pessoas.data?.find((p) => p.colaborador_id === pessoaId) ?? pessoas.data?.[0];
  const ehSre = pessoa?.papel.toLowerCase() === 'sre';
  // A causa que essa pessoa ajuda a destravar: SRE resolve falta de SRE; os demais papéis, rotatividade.
  const causa = ehSre ? 'falta_sre' : 'rotatividade';

  // Destinos: só projetos em atenção ou crítico, ordenados pelos dias de impacto da causa
  const destinos = useMemo(() => {
    const emRisco = (projetos.data ?? []).filter((p) => p.situacao === 'atenção' || p.situacao === 'crítico');
    const dias = (p: (typeof emRisco)[number]) => num(ehSre ? p.dias_falta_sre : p.dias_rotatividade);
    return [...emRisco].sort((a, b) => dias(b) - dias(a));
  }, [projetos.data, ehSre]);

  const destino = destinos.find((p) => p.projeto_id === destinoId) ?? destinos[0];

  const carregando = pessoas.loading || projetos.loading;
  const erro = pessoas.error ?? projetos.error;

  // A conta
  const horasMes = num(pessoa?.horas_paradas_semana) * SEMANAS_NO_MES;
  const ociosidadeEvitada = num(pessoa?.custo_ocioso_semana) * SEMANAS_NO_MES;
  const diasImpacto90 = num(ehSre ? destino?.dias_falta_sre : destino?.dias_rotatividade);
  const diasRecuperados = (diasImpacto90 / 90) * 30;
  const horasOnb = Math.max(0, num(horasOnboarding));
  const mobilizacao = horasOnb * num(pessoa?.custo_hora);
  const saldo = ociosidadeEvitada - mobilizacao;

  return (
    <div className="space-y-6 w-full max-w-5xl mx-auto">
      <div>
        <h2 className="text-2xl font-semibold">Tenho gente parada enquanto outro projeto pede gente?</h2>
        <p className="text-sm text-muted-foreground">
          Simule mover uma pessoa com utilização abaixo de 20% (últimas 12 semanas até {HOJE}) para um projeto em atenção ou
          crítico. Valores por mês (4 semanas).
        </p>
      </div>

      {erro && (
        <Alert variant="destructive">
          <AlertTitle>Não foi possível ler os dados</AlertTitle>
          <AlertDescription>{erro}</AlertDescription>
        </Alert>
      )}

      {carregando && <Skeleton className="h-40 w-full" />}

      {!carregando && !erro && (pessoas.data?.length ?? 0) === 0 && (
        <Empty>
          <EmptyHeader>
            <EmptyTitle>Ninguém parado</EmptyTitle>
            <EmptyDescription>Nenhuma pessoa com utilização abaixo de 20% nas últimas 12 semanas.</EmptyDescription>
          </EmptyHeader>
        </Empty>
      )}

      {!carregando && pessoa && destino && (
        <>
          <Card>
            <CardContent className="pt-6 grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="space-y-2">
                <Label htmlFor="pessoa">Pessoa ociosa</Label>
                <Select value={pessoa.colaborador_id} onValueChange={setPessoaId}>
                  <SelectTrigger id="pessoa">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {pessoas.data?.map((p) => (
                      <SelectItem key={p.colaborador_id} value={p.colaborador_id}>
                        {p.colaborador_id} · {p.nome} ({p.papel}, {p.projeto_id}, uso {fmtPercentual(p.utilizacao)})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="destino">Projeto destino</Label>
                <Select value={destino.projeto_id} onValueChange={setDestinoId}>
                  <SelectTrigger id="destino">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {destinos.map((p) => (
                      <SelectItem key={p.projeto_id} value={p.projeto_id}>
                        {p.projeto_id} · {p.situacao} · SPI {fmtIndice(p.spi)} ·{' '}
                        {fmtInteiro(ehSre ? p.dias_falta_sre : p.dias_rotatividade)} dias de {NOME_CAUSA[causa]}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="onboarding">Horas de onboarding</Label>
                <Input
                  id="onboarding"
                  type="number"
                  min={0}
                  value={horasOnboarding}
                  onChange={(e) => setHorasOnboarding(e.target.value)}
                />
              </div>
            </CardContent>
          </Card>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
            <Resultado titulo="Horas no mês" valor={`${fmtInteiro(horasMes)} h`} detalhe="horas paradas por semana × 4" />
            <Resultado
              titulo="Ociosidade que deixa de ser paga"
              valor={fmtReaisInteiro(ociosidadeEvitada)}
              detalhe="custo ocioso por semana × 4"
              destaque="bom"
            />
            <Resultado
              titulo="Cronograma recuperado"
              valor={`${fmtDecimal1(diasRecuperados)} dias`}
              detalhe={`${fmtInteiro(diasImpacto90)} dias de ${NOME_CAUSA[causa]} em 90 dias ÷ 90 × 30`}
            />
            <Resultado
              titulo="Mobilização"
              valor={fmtReaisInteiro(mobilizacao)}
              detalhe={`${fmtInteiro(horasOnb)} h de onboarding × custo/hora`}
              destaque="ruim"
            />
            <Resultado
              titulo="Saldo no mês"
              valor={fmtReaisInteiro(saldo)}
              detalhe="ociosidade evitada − mobilização"
              destaque={saldo >= 0 ? 'bom' : 'ruim'}
            />
          </div>

          <Card>
            <CardHeader>
              <CardTitle className="text-base">De onde vem cada número</CardTitle>
            </CardHeader>
            <CardContent>
              <details className="text-sm space-y-2">
                <summary className="cursor-pointer font-medium">Explicar a conta</summary>
                <ul className="list-disc pl-5 space-y-1 mt-2 text-muted-foreground">
                  <li>
                    <strong>Horas no mês</strong>: {pessoa.nome} ficou em média {fmtDecimal1(pessoa.horas_paradas_semana)} h
                    paradas por semana nas últimas 12 semanas (gold.utilizacao_pessoa_semana) × 4 semanas ={' '}
                    {fmtInteiro(horasMes)} h.
                  </li>
                  <li>
                    <strong>Ociosidade que deixa de ser paga</strong>: custo ocioso médio de{' '}
                    {fmtReaisInteiro(pessoa.custo_ocioso_semana)} por semana (horas paradas × custo/hora de{' '}
                    {fmtReaisInteiro(pessoa.custo_hora)}) × 4 = {fmtReaisInteiro(ociosidadeEvitada)}.
                  </li>
                  <li>
                    <strong>Cronograma recuperado</strong>: o gerente do {destino.projeto_id} declarou{' '}
                    {fmtInteiro(diasImpacto90)} dias de impacto por {NOME_CAUSA[causa]} nos últimos 90 dias
                    (gold.status_estruturado). Por mês: {fmtInteiro(diasImpacto90)} ÷ 90 × 30 = {fmtDecimal1(diasRecuperados)}{' '}
                    dias. Dias de cronograma não viram R$ sem premissa, por isso ficam fora do saldo.
                  </li>
                  <li>
                    <strong>Mobilização</strong>: {fmtInteiro(horasOnb)} h de onboarding × {fmtReaisInteiro(pessoa.custo_hora)}/h ={' '}
                    {fmtReaisInteiro(mobilizacao)}.
                  </li>
                  <li>
                    <strong>Saldo</strong>: {fmtReaisInteiro(ociosidadeEvitada)} − {fmtReaisInteiro(mobilizacao)} ={' '}
                    {fmtReaisInteiro(saldo)} no primeiro mês.
                  </li>
                </ul>
              </details>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}

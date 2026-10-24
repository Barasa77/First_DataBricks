import { useEffect, useState } from 'react';

// O warehouse devolve número como string: tudo passa por num() antes de conta ou formatação.
export const num = (valor: unknown): number => {
  const n = Number(valor);
  return Number.isFinite(n) ? n : 0;
};

export const verdadeiro = (valor: unknown): boolean => String(valor) === 'true';

const reaisCompacto = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
  notation: 'compact',
  maximumFractionDigits: 1,
});
const reaisInteiro = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 });
const decimal2 = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const decimal1 = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const inteiro = new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 0 });
const percentual = new Intl.NumberFormat('pt-BR', { style: 'percent', maximumFractionDigits: 0 });

/** R$ 6,5 mi */
export const fmtReais = (v: unknown) => reaisCompacto.format(num(v));
/** R$ 30.123 */
export const fmtReaisInteiro = (v: unknown) => reaisInteiro.format(num(v));
/** índices (SPI, CPI) com 2 casas */
export const fmtIndice = (v: unknown) => decimal2.format(num(v));
export const fmtDecimal1 = (v: unknown) => decimal1.format(num(v));
export const fmtInteiro = (v: unknown) => inteiro.format(num(v));
/** 0,46 → 46% */
export const fmtPercentual = (v: unknown) => percentual.format(num(v));

export const HOJE = '16/10/2026';

export const NOME_CAUSA: Record<string, string> = {
  change_freeze: 'change freeze',
  falta_sre: 'falta de SRE',
  dependencia_fornecedor: 'dependência de fornecedor',
  rotatividade: 'rotatividade',
  mudanca_escopo: 'mudança de escopo',
  bug_retrabalho: 'bug / retrabalho',
  aprovacao_cliente: 'aprovação do cliente',
};

// ---------------------------------------------------------------------------
// Score do modelo (opcional): rota do servidor, nunca config/queries
// ---------------------------------------------------------------------------
export type LinhaScore = {
  projeto_id: string;
  prob_estouro_30d: number;
  ranking: number;
  faixa_risco: string;
  principais_fatores: string | null;
};

type EstadoScore = { carregando: boolean; disponivel: boolean; linhas: LinhaScore[] };

const ehRespostaScore = (x: unknown): x is { disponivel: boolean; linhas: LinhaScore[] } =>
  typeof x === 'object' && x !== null && 'disponivel' in x && 'linhas' in x && Array.isArray(x.linhas);

export function useScoreEstouro(): EstadoScore {
  const [estado, setEstado] = useState<EstadoScore>({ carregando: true, disponivel: false, linhas: [] });

  useEffect(() => {
    let ativo = true;
    fetch('/api/score-estouro')
      .then((r) => r.json())
      .then((corpo: unknown) => {
        if (!ativo) return;
        if (ehRespostaScore(corpo) && corpo.disponivel) {
          setEstado({ carregando: false, disponivel: true, linhas: corpo.linhas });
        } else {
          setEstado({ carregando: false, disponivel: false, linhas: [] });
        }
      })
      .catch(() => ativo && setEstado({ carregando: false, disponivel: false, linhas: [] }));
    return () => {
      ativo = false;
    };
  }, []);

  return estado;
}

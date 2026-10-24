import { useEffect, useState } from 'react';
import { Badge, Card, CardContent, CardDescription, CardHeader, CardTitle, GenieChat } from '@databricks/appkit-ui/react';

type Identidade = { email: string | null; user: string | null };

const ehIdentidade = (x: unknown): x is Identidade => typeof x === 'object' && x !== null && 'email' in x;

export function PerguntarPage() {
  const [eu, setEu] = useState<Identidade | null>(null);

  useEffect(() => {
    fetch('/api/whoami')
      .then((r) => (r.ok ? r.json() : null))
      .then((corpo: unknown) => setEu(ehIdentidade(corpo) ? corpo : null))
      .catch(() => setEu(null));
  }, []);

  return (
    <div className="space-y-4 w-full max-w-5xl mx-auto">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-2xl font-semibold">Pergunte em português</h2>
          <p className="text-sm text-muted-foreground">
            O agente <strong>Farol · Diretoria</strong> responde sobre atraso, custo, gente parada, fornecedores e o que vai dar errado no
            próximo mês. Hoje = 16/10/2026.
          </p>
        </div>
        <Badge variant="secondary">{eu?.email ?? eu?.user ?? 'usuário conectado'}</Badge>
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base">Farol · Diretoria</CardTitle>
          <CardDescription>
            As perguntas rodam com as SUAS permissões no Unity Catalog (em seu nome, não do app). Cada resposta mostra o SQL
            que a gerou: confira antes de decidir.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="h-[600px]">
            <GenieChat alias="default" placeholder="Ex.: Quais projetos estão atrasados, e de quais clientes?" />
          </div>
          <p className="mt-2 text-xs text-muted-foreground">
            Respostas geradas por IA (Genie) a partir da gold: podem errar. Revise o SQL de cada resposta antes de confiar no
            número.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}

# Simone Conversão App

Linktree premium com infraestrutura completa de CRM, tracking, lead scoring e autenticação com Google.

## O que já vem pronto

✅ **Next.js App Router** com TypeScript  
✅ **Login com Google** via Auth.js/NextAuth  
✅ **Prisma ORM** + PostgreSQL (Supabase)  
✅ **Sistema de tracking** (eventos, UTMs, sesões)  
✅ **CRM completo** com score de lead e temperatura  
✅ **Dashboard protegido** com insights  
✅ **Formulário de captura** com validação Zod  
✅ **Rate limiting** anti-abuso com LRU cache  
✅ **Headers de segurança** (CSP, X-Frame-Options, etc)  
✅ **Design premium** feminino terapêutico  
✅ **Estrutura escalável** pronta para novas páginas  

## Stack

- **Frontend**: Next.js 15, React 19, Tailwind CSS, TypeScript
- **Backend**: Next.js API Routes
- **Database**: PostgreSQL (Supabase)
- **ORM**: Prisma
- **Auth**: NextAuth/Auth.js com Google OAuth
- **Forms**: React Hook Form + Zod
- **Email**: Resend (opcional)
- **Utils**: Lucide icons, clsx, tailwind-merge, LRU cache

## Quickstart

### 1. Clone e instale

```bash
cd site-simone-app
npm install
```

### 2. Configure o `.env`

Copie `.env.example` para `.env` e preencha:

```env
# Google OAuth
AUTH_GOOGLE_ID=seu_client_id
AUTH_GOOGLE_SECRET=seu_client_secret
AUTH_SECRET=gere_um_secret_forte_aqui

# Supabase PostgreSQL
DATABASE_URL=postgresql://user:password@host/db?pgbouncer=true
DIRECT_URL=postgresql://user:password@host/db

# App
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXT_PUBLIC_WHATSAPP_URL=https://wa.me/55...

# Email (opcional)
RESEND_API_KEY=sua_chave_resend
RESEND_FROM=seu_email
SALES_NOTIFICATION_EMAIL=email_vendas
```

### 3. Setup banco de dados

```bash
npx prisma generate
npx prisma db push
```

### 4. Rode em desenvolvimento

```bash
npm run dev
```

Acesse http://localhost:3000

## Estrutura

```
app/
  api/
    auth/[...nextauth]/  → Google login
    track/               → Tracking de eventos
    leads/               → Criação/update de leads
    dashboard/summary/   → Stats do dashboard
    health/              → Health check
  dashboard/             → Área protegida
  signin/                → Login page
  layout.tsx             → Root layout com Header
  page.tsx               → Home (linktree)
  globals.css            → Estilos globais

components/
  layout/Header.tsx      → Header com nav
  analytics/             → Tracking components
  forms/LeadCaptureForm/ → Formulário
  Hero.tsx               → Hero section

lib/
  prisma.ts              → Singleton Prisma
  env.ts                 → Validação de env vars
  utils.ts               → Helpers (cn, formatDate)
  rate-limit.ts          → Rate limiting
  score.ts               → Lógica de scoring
  tracking.ts            → Tracking client-side
  email.ts               → Notificação de leads

prisma/
  schema.prisma          → Modelos: User, Lead, PageEvent, etc
```

## Features

### Tracking Automático

- `page_view` - Carregamento de página
- `mock_link_click` - Clique em link
- `lead_form_submit` - Envio de formulário
- `lead_created` - Lead criado no CRM

Todos os eventos capturam:
- UTM parameters
- Session ID
- Anonymous ID  
- Referrer
- User Agent (hash)
- Metadados customizados

### CRM de Leads

Cada lead tem:
- **Score**: Calculado por eventos + nível de interesse
- **Temperatura**: COLD (0-34) | WARM (35-64) | HOT (65+)
- **Status**: NEW → CONTACTED → NURTURING → QUALIFIED → CONVERTED
- **Consentimento**: Analytics + Marketing
- **Histórico**: Atividades registradas

### Dashboard

Protegido por autenticação. Mostra:
- Total de leads
- Leads quentes e mornos
- Total de eventos
- Tabela de últimos leads com scores

## Segurança

- ✅ **Rate limiting**: 120 events/min, 8 leads/15min por IP
- ✅ **Honeypot**: Campo anti-bot oculto
- ✅ **Hash de IP**: SHA256 com salt
- ✅ **CSP Headers**: Restrição de scripts/styles
- ✅ **Validação Zod**: Todos os inputs
- ✅ **Middleware**: Proteção de rotas `/dashboard`

## Próximos Passos

1. **Substituir vídeo hero** - Troque `/public/video-secao-hero.mp4`
2. **Atualizar logo** - Customize `/public/logo-sm.svg`
3. **Google Console** - Registre domínio e URLs de callback
4. **Supabase setup** - Crie projeto e configure variáveis
5. **Deploy** - Vercel, Netlify, ou seu servidor

## Scripts

```bash
npm run dev         # Desenvolvimento
npm run build       # Build
npm run start       # Produção
npm run lint        # Linting
npm run db:generate # Gerar Prisma client
npm run db:push     # Sincronizar schema
npm run db:migrate  # Criar migration
npm run db:studio   # Prisma Studio UI
```

## Variáveis de Ambiente

| Variável | Descrição | Obrigatória |
|----------|-----------|-------------|
| `DATABASE_URL` | Connection string pooled | ✅ |
| `DIRECT_URL` | Connection string direct | ✅ |
| `AUTH_SECRET` | NextAuth secret | ✅ |
| `AUTH_GOOGLE_ID` | Google OAuth Client ID | ✅ |
| `AUTH_GOOGLE_SECRET` | Google OAuth Client Secret | ✅ |
| `NEXT_PUBLIC_APP_URL` | URL da app (público) | ✅ |
| `NEXT_PUBLIC_SITE_NAME` | Nome do site | ❌ |
| `NEXT_PUBLIC_WHATSAPP_URL` | Link WhatsApp | ❌ |
| `RESEND_API_KEY` | Chave Resend para email | ❌ |
| `RESEND_FROM` | Email remetente | ❌ |
| `SALES_NOTIFICATION_EMAIL` | Email de notificação | ❌ |

## Troubleshooting

**Erro: "Unable to require(...)prisma"**
```bash
npx prisma generate
```

**Erro: "Connection timeout"**
- Verifique `DATABASE_URL` e `DIRECT_URL` no `.env`
- Teste a conexão: `psql $DATABASE_URL`

**Erro: "Google login failed"**
- Confirme `AUTH_GOOGLE_ID` e `AUTH_GOOGLE_SECRET` corretos
- Adicione `http://localhost:3000/api/auth/callback/google` em Google Console

**Erro: "Module not found"**
```bash
rm -rf .next node_modules
npm install
npm run build
```

## Performance

- ✅ Image optimization (Next.js)
- ✅ Font optimization (Google Fonts)
- ✅ Async tracking (sendBeacon)
- ✅ Rate limiting memory efficient
- ✅ Renderização SSR/ISR
- ✅ API streaming pronto

## Licença

Premium project template. Customiza conforme necessário.

## Suporte

Para problemas, revise:
1. Logs do terminal
2. Variáveis de ambiente (`.env`)
3. Conexão do banco
4. Credenciais Google OAuth

---

**Criado com ❤️ para Simone Matos • Super Conversão**

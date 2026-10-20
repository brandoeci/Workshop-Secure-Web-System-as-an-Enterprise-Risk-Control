# Local evidence (not the graded deliverables)

These were captured in a real browser against the application running locally,
before the Auth0 tenant and the public host existed. They show the controls
working; they are **not** the two screenshots the workshop asks for, because
those must come from the deployed HTTPS address with a real Auth0 login.

| File | What it shows |
| --- | --- |
| `01-app-unauthenticated.png` | The client with no session. It holds no credentials of its own — the only way in is through Auth0. |
| `02-unauthenticated-401.png` | The same client calling `/api/risk-status` with no `Authorization` header: **HTTP 401**. The control, visible in the UI. |

The command-line evidence that goes with these is in
[../../local-verification.md](../../local-verification.md) and
[../../server-rehearsal.md](../../server-rehearsal.md).

Still required, in the parent folder, once the site is deployed:
`authenticated-api-call.png` and `valid-certificate.png` — see
[../README.md](../README.md).

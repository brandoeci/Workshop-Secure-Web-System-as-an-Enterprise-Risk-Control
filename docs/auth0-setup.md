# Part 1 — Auth0 configuration

Create the API before the application. The API declares the permission; the
application is then explicitly granted it.

## 1. Create the API

**Applications → APIs → Create API**

| Field | Value |
| --- | --- |
| Name | `Enterprise Risk Lab API` |
| Identifier (audience) | `https://enterprise-risk-api` |
| Signing algorithm | `RS256` |

The identifier is not a URL that gets called — it is the name the backend
answers to. It must match byte for byte in three places: Auth0, the React
`VITE_AUTH0_AUDIENCE`, and the Spring `...jwt.audiences` property. RS256 means
the token is signed with Auth0's private key and the API verifies it with the
public key it fetches from the tenant's JWKS, so the API never holds a shared
secret.

## 2. Define the permission

**Your API → Permissions**

| Permission | Description |
| --- | --- |
| `read:risk` | Read the protected risk status |

The API is the resource; `read:risk` is one allowed action on it.

## 3. Create the browser client

**Applications → Applications → Create Application → Single Page Web Application**,
named `Enterprise Risk Lab Frontend`. In its settings:

```
Allowed Callback URLs
http://localhost:5173,https://YOUR-SUBDOMAIN.duckdns.org

Allowed Logout URLs
http://localhost:5173,https://YOUR-SUBDOMAIN.duckdns.org

Allowed Web Origins
http://localhost:5173,https://YOUR-SUBDOMAIN.duckdns.org
```

These lists are what stops an attacker's page from completing a login flow with
your tenant and walking away with a token. Keep them exact — no wildcards.

## 4. Grant the SPA access to the API

**Applications → Applications → Enterprise Risk Lab Frontend → APIs →
Enterprise Risk Lab API → Edit**

Under **User-Delegated Access** choose **Grant Access**, select `read:risk`
(or *All* for this lab), and save.

User-delegated access is the right grant because the SPA acts *on behalf of a
signed-in person*. The green check under Client Access is the machine-to-machine
grant (client credentials) and does not authorize a browser login. Without the
user-delegated grant, Auth0 returns:

```
Client "..." is not authorized to access resource server "https://enterprise-risk-api"
```

## 5. Record the client configuration

```
AUTH0_DOMAIN=YOUR_TENANT.us.auth0.com
AUTH0_CLIENT_ID=...
AUTH0_AUDIENCE=https://enterprise-risk-api
```

The domain, client ID and audience ship inside the browser bundle, and that is
fine — they are identifiers, not credentials. **Never put an Auth0 client secret
in a single page application**: everything the browser downloads is readable by
whoever is using it.

## 6. Create a test user

**Authentication → Database → Users → Create User**, on the
`Username-Password-Authentication` connection. Use that account to log in
through the React application.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `Client "..." is not authorized to access resource server` | Step 4 is missing. Grant **User-Delegated Access**; Client Access alone does not authorize a browser login. |
| `Request failed: JSON.parse: unexpected end of data` | Spring rejected the token and returned an empty body. The `callApi` in [frontend/src/App.jsx](../frontend/src/App.jsx) already reads the body as text first and reports the real status. |
| `API returned 401` | Check that the issuer URI includes `https://` **and** the trailing slash, that the audience is exactly `https://enterprise-risk-api`, and restart the backend after changing properties — they are read at startup. |
| Login works, API call fails from `localhost:5173` | CORS. `app.cors.allowed-origins` must include `http://localhost:5173`; restart the backend. |
| `access_denied` / no user can sign in | Create the test user, or enable another connection for the SPA. Roles are not needed unless you add permission checks to the backend. |
| Token has no `read:risk` scope | The scope is requested in [frontend/src/main.jsx](../frontend/src/main.jsx). It only appears in the token once step 4 is done. |

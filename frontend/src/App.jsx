import { useState } from 'react';
import { useAuth0 } from '@auth0/auth0-react';

const API_URL = import.meta.env.VITE_API_URL;

export default function App() {
  const {
    loginWithRedirect,
    logout,
    isAuthenticated,
    isLoading,
    error,
    user,
    getAccessTokenSilently,
  } = useAuth0();
  const [result, setResult] = useState('');

  /** Authenticated call: the access token travels in the Authorization header. */
  async function callApi() {
    try {
      const token = await getAccessTokenSilently();
      const response = await fetch(`${API_URL}/api/risk-status`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const body = await response.text();
      if (!response.ok) {
        throw new Error(`API returned ${response.status}${body ? `: ${body}` : ''}`);
      }
      setResult(JSON.stringify(JSON.parse(body), null, 2));
    } catch (err) {
      setResult(`Request failed: ${err.message}`);
    }
  }

  /** Same endpoint, no token: evidence that the API denies anonymous callers. */
  async function callApiWithoutToken() {
    try {
      const response = await fetch(`${API_URL}/api/risk-status`);
      const body = await response.text();
      setResult(`No Authorization header -> HTTP ${response.status} ${response.statusText}${body ? `\n${body}` : ''}`);
    } catch (err) {
      setResult(`Request failed: ${err.message}`);
    }
  }

  if (isLoading) return <main className="card"><p>Loading…</p></main>;

  if (error) {
    return (
      <main className="card">
        <h1>Enterprise Risk Lab</h1>
        <p className="error">Auth0 error: {error.message}</p>
      </main>
    );
  }

  if (!isAuthenticated) {
    return (
      <main className="card">
        <h1>Enterprise Risk Lab</h1>
        <p>This client holds no credentials of its own. Identity is proven at Auth0.</p>
        <div className="actions">
          <button onClick={() => loginWithRedirect()}>Log in</button>
          <button className="secondary" onClick={callApiWithoutToken}>
            Call protected API without a token
          </button>
        </div>
        {result && <pre>{result}</pre>}
      </main>
    );
  }

  return (
    <main className="card">
      <h1>Enterprise Risk Lab</h1>
      <p>
        Signed in as <strong>{user?.name ?? user?.email ?? user?.sub}</strong>
      </p>
      <div className="actions">
        <button onClick={callApi}>Call protected API</button>
        <button className="secondary" onClick={callApiWithoutToken}>
          Call without a token
        </button>
        <button
          className="secondary"
          onClick={() => logout({ logoutParams: { returnTo: window.location.origin } })}
        >
          Log out
        </button>
      </div>
      {result && <pre>{result}</pre>}
    </main>
  );
}

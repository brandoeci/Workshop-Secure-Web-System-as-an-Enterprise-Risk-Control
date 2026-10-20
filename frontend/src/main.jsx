import React from 'react';
import ReactDOM from 'react-dom/client';
import { Auth0Provider } from '@auth0/auth0-react';
import App from './App.jsx';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <Auth0Provider
    domain={import.meta.env.VITE_AUTH0_DOMAIN}
    clientId={import.meta.env.VITE_AUTH0_CLIENT_ID}
    authorizationParams={{
      redirect_uri: window.location.origin,
      // The audience is what makes Auth0 issue a JWT access token for OUR API
      // instead of an opaque token only valid against /userinfo.
      audience: import.meta.env.VITE_AUTH0_AUDIENCE,
      scope: 'openid profile email read:risk',
    }}
  >
    <App />
  </Auth0Provider>
);

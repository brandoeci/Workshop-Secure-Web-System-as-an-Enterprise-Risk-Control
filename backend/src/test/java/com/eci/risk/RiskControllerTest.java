package com.eci.risk;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Proves the two controls the workshop claims: the endpoint rejects anonymous callers, and an
 * authenticated caller gets their own subject back. The decoder is mocked so the test never calls
 * out to Auth0; issuer and audience validation is Spring's own, configured in
 * application.properties.
 */
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "spring.security.oauth2.resourceserver.jwt.issuer-uri=https://test-tenant.us.auth0.com/",
    "app.cors.allowed-origins=http://localhost:5173"
})
class RiskControllerTest {

  @Autowired
  private MockMvc mockMvc;

  @MockBean
  private JwtDecoder jwtDecoder;

  @Test
  void anonymousRequestIsRejected() throws Exception {
    mockMvc.perform(get("/api/risk-status"))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void authenticatedRequestReturnsTheCallerSubject() throws Exception {
    mockMvc.perform(get("/api/risk-status")
            .with(jwt().jwt(builder -> builder.subject("auth0|workshop-test-user"))))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("protected"))
        .andExpect(jsonPath("$.subject").value("auth0|workshop-test-user"));
  }

  @Test
  void healthEndpointIsPublic() throws Exception {
    mockMvc.perform(get("/actuator/health"))
        .andExpect(status().isOk());
  }

  @Test
  void undeclaredPathsAreDenied() throws Exception {
    mockMvc.perform(get("/internal/secrets")
            .with(jwt()))
        .andExpect(status().isForbidden());
  }
}

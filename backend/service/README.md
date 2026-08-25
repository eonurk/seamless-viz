# seAMLess API service

The Node service authenticates requests, manages uploads, and proxies analysis
calls to the R compute backend.

For standalone development, enable the built-in local identity:

```bash
export SEAMLESS_DEV_AUTH=1
export SEAMLESS_DEV_USER_EMAIL=dev@localhost
npm install
npm run start
```

Real Firebase authentication can instead be configured with
`SEAMLESS_FIREBASE_CREDENTIALS` pointing to a service-account JSON file. The
Docker Compose workflow configures this service automatically.

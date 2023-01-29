import { Signer } from '@aws-amplify/core';

const aws4Interceptor = (options, credentials) => (cfg) => {
  const request = {
    method: cfg.method.toUpperCase(),
    url: options.signingUrl,
    data: cfg.data,
  };
  const accessInfo = {
    access_key: credentials.accessKeyId,
    secret_key: credentials.secretAccessKey,
    session_token: credentials.sessionToken,
  };
  const serviceInfo = {
    service: options.service,
    region: options.region,
  };

  const signedRequest = Signer.sign(request, accessInfo, serviceInfo);

  // delete unsafe host header
  delete signedRequest.headers["host"];

  cfg.headers = { ...cfg.headers, ...signedRequest.headers };

  return cfg;
};

export default aws4Interceptor;
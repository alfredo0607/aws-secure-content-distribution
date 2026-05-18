import { getSignedUrl } from '@aws-sdk/cloudfront-signer';
import fs from 'fs';
import { CLOUDFRONT_KEYPAIR_ID, CLOUDFRONT_PRIVATE_KEY } from '../../../config.js';

async function firmarUrl(url, expiresInSeconds = 86400) {
  console.info(CLOUDFRONT_PRIVATE_KEY);

  const signedUrl = await getSignedUrl({
    url,
    dateLessThan: new Date(Date.now() + expiresInSeconds * 1000),
    privateKey: fs.readFileSync(CLOUDFRONT_PRIVATE_KEY),
    keyPairId: CLOUDFRONT_KEYPAIR_ID,
  });

  return signedUrl;
}

export default firmarUrl;

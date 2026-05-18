import { getSignedUrl } from "@aws-sdk/cloudfront-signer";
import fs from "fs";
import {
  CLOUDFRONT_KEYPAIR_ID,
  CLOUDFRONT_PRIVATE_KEY,
} from "../../../config.js";

async function firmarUrl(url) {
  try {
    const signedUrl = await getSignedUrl({
      url: url,
      dateLessThan: new Date(Date.now() + 1000 * 60 * 60 * 24),
      privateKey: fs.readFileSync(CLOUDFRONT_PRIVATE_KEY),
      keyPairId: CLOUDFRONT_KEYPAIR_ID,
    });

    return signedUrl;
  } catch (error) {
    console.error(error);
  }
}

export default firmarUrl;

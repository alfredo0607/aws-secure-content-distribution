import { CLOUDFRONT_DOMAIN } from '../../config.js';
import firmarUrl from '../AWS/cloudfront/index.js';
import { deleteFileS3, listFilesS3 } from '../AWS/S3/index.js';
import { uploadFile } from '../helpers/uploadFile.helper.js';
import { AppError } from '../middlewares/errorHandler.js';

const FOLDER = 'uploads/';
const DEFAULT_EXPIRES = 86400; // 24 h

export async function uploadFileService(file) {
  const result = await uploadFile(FOLDER, file);

  if (!result.success) {
    throw new AppError(result.error || 'Upload failed', 500, 'UPLOAD_FAILED');
  }

  return { key: result.fileName };
}

export async function getSignedUrlService(filename, expiresInSeconds = DEFAULT_EXPIRES) {
  if (!CLOUDFRONT_DOMAIN) {
    throw new AppError('CloudFront domain is not configured', 500, 'CONFIG_ERROR');
  }

  const url = `${CLOUDFRONT_DOMAIN}/${FOLDER}${filename}`;

  const signedUrl = await firmarUrl(url, expiresInSeconds);

  console.info(signedUrl);

  return { signedUrl, expiresIn: expiresInSeconds };
}

export async function listFilesService() {
  const result = await listFilesS3(FOLDER);

  if (!result.success) {
    throw new AppError(result.error || 'List failed', 500, 'LIST_FAILED');
  }

  return result.files.map((f) => ({
    key: f.Key.replace(FOLDER, ''),
    size: f.Size,
    lastModified: f.LastModified,
  }));
}

export async function deleteFileService(filename) {
  const result = await deleteFileS3(`${FOLDER}${filename}`);

  if (!result.success) {
    throw new AppError(result.error || 'Delete failed', 500, 'DELETE_FAILED');
  }
}

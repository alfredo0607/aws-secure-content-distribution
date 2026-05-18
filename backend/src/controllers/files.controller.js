import { AppError } from '../middlewares/errorHandler.js';
import {
  deleteFileService,
  getSignedUrlService,
  listFilesService,
  uploadFileService,
} from '../services/files.service.js';

export async function uploadFile(req, res, next) {
  try {
    if (!req.files?.file) {
      throw new AppError('No file attached. Use field name "file".', 400, 'FILE_MISSING');
    }

    const data = await uploadFileService(req.files.file);

    return res.status(201).json({
      message: 'File uploaded successfully',
      data,
    });
  } catch (err) {
    next(err);
  }
}

export async function getSignedUrl(req, res, next) {
  try {
    const { key } = req.params;
    const expires = req.query.expires ? parseInt(req.query.expires, 10) : undefined;

    if (expires !== undefined && (isNaN(expires) || expires <= 0)) {
      throw new AppError('"expires" must be a positive integer (seconds).', 400, 'INVALID_PARAM');
    }

    const data = await getSignedUrlService(key, expires);

    return res.status(200).json({
      message: 'Signed URL generated',
      data,
    });
  } catch (err) {
    next(err);
  }
}

export async function listFiles(req, res, next) {
  try {
    const data = await listFilesService();

    return res.status(200).json({
      message: 'Files retrieved',
      data,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteFile(req, res, next) {
  try {
    const { key } = req.params;

    await deleteFileService(key);

    return res.status(200).json({
      message: 'File deleted successfully',
    });
  } catch (err) {
    next(err);
  }
}

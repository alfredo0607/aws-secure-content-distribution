import { Router } from 'express';
import {
  deleteFile,
  getSignedUrl,
  listFiles,
  uploadFile,
} from '../controllers/files.controller.js';

const router = Router();

// POST   /api/v1/files/upload         → sube un archivo a S3
// GET    /api/v1/files                → lista archivos del bucket
// GET    /api/v1/files/:key/signed-url → genera Signed URL de CloudFront
// DELETE /api/v1/files/:key           → elimina un archivo del bucket

router.post('/upload', uploadFile);
router.get('/', listFiles);
router.get('/:key/signed-url', getSignedUrl);
router.delete('/:key', deleteFile);

export default router;

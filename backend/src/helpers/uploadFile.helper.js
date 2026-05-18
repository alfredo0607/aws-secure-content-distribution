import sharp from 'sharp';
import { generateFileName } from './codeGenerator.helper.js';
import { uploadFileS3 } from '../AWS/S3/index.js';

export const exteValidateImg = ['jpeg', 'png', 'webp', 'avif', 'gif', 'svg', 'tiff', 'jpg'];

export async function compressAndUploadImg(file) {
  let quality;

  const imagenBuffer = file.data;

  const size = file.size / (1024 * 1024);
  const formatterSize = decimalAEntero(size);

  if (formatterSize >= 2) {
    quality = 30;
  } else if (formatterSize >= 1 && formatterSize <= 2) {
    quality = 60;
  } else {
    quality = 100;
  }

  const imagenComprimida = await sharp(imagenBuffer).jpeg({ quality: quality }).toBuffer();

  return { data: imagenComprimida, mimetype: file.mimetype };
}

function decimalAEntero(decimal) {
  return Math.floor(decimal);
}

export const uploadFile = async (path, file) => {
  try {
    if (!file || !file.name || !file.mimetype) {
      throw new Error('Invalid file object');
    }

    let fileCompress = null;

    const arrayFile = file.name.split('.');
    const extensionName = arrayFile[arrayFile.length - 1];

    const nombreServidor = generateFileName(file.md5, extensionName);

    const extension = file.mimetype.split('/')[1];

    if (exteValidateImg.includes(extension)) {
      fileCompress = await compressAndUploadImg(file);
    } else {
      fileCompress = file;
    }

    const res = await uploadFileS3(path, nombreServidor, fileCompress);

    if (!res.success) {
      throw new Error(res.error || 'Upload to S3 failed');
    }

    return {
      success: true,
      fileName: nombreServidor,
    };
  } catch (error) {
    console.error('Error in uploadFile:', error);

    return {
      success: false,
      error: error.message || 'Unknown error',
    };
  }
};

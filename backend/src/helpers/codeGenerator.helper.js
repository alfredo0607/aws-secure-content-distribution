import { customAlphabet, nanoid } from 'nanoid';

const nanoidCustom = customAlphabet('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 12);

export const generateCode = () => customAlphabet('1234567890', 4)();

export const generateFileName = (md5File, fileExtension) =>
  nanoid() + md5File + '.' + fileExtension;

export const generateSessionCode = () => {
  const id = nanoidCustom();

  return `${id.slice(0, 4)}-${id.slice(4, 8)}-${id.slice(8, 12)}`;
};

export const generateOTP = () => customAlphabet('1234567890', 6)();

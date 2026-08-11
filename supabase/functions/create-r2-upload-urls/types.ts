export type ErrorCode =
  | "UNAUTHENTICATED"
  | "ADMIN_ACCESS_REQUIRED"
  | "INVALID_REQUEST"
  | "CATEGORY_NOT_FOUND"
  | "UNSUPPORTED_MEDIA_TYPE"
  | "FILE_TOO_LARGE"
  | "TOO_MANY_FILES"
  | "INTERNAL_ERROR"
  | "CONFIGURATION_ERROR";

export interface UploadFileRequest {
  fileName: string;
  contentType: string;
  sizeBytes: number;
}

export interface CreateUploadUrlsRequest {
  category: string;
  files: UploadFileRequest[];
}

export interface UploadUrlItem {
  clientFileName: string;
  contentType: string;
  objectKey: string;
  uploadUrl: string;
  publicUrl: string;
}

export interface CreateUploadUrlsResponse {
  items: UploadUrlItem[];
}

export interface ErrorResponse {
  error: ErrorCode;
  message?: string;
  fileName?: string;
}

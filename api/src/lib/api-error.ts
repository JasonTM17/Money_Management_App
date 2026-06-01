export class ApiError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details?: Record<string, unknown>,
  ) {
    super(message);
  }
}

export function badRequest(
  code: string,
  message: string,
  details?: Record<string, unknown>,
) {
  return new ApiError(400, code, message, details);
}

export function unauthorized(message = 'Authentication required') {
  return new ApiError(401, 'unauthorized', message);
}

export function conflict(
  code: string,
  message: string,
  details?: Record<string, unknown>,
) {
  return new ApiError(409, code, message, details);
}

export function forbidden(code: string, message: string) {
  return new ApiError(403, code, message);
}

export function notFound(code: string, message: string) {
  return new ApiError(404, code, message);
}

export function serviceUnavailable(code: string, message: string) {
  return new ApiError(503, code, message);
}

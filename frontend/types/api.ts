export type ApiError = {
  code: string;
  message: string;
  details?: {
    fields?: Record<string, string[]>;
    [key: string]: unknown;
  };
};

export type ApiErrorResponse = {
  error?: ApiError;
};

export interface PaginatedResponse<T> {
  data: T[];
  meta: {
    page: number;
    per_page: number;
    total_count: number;
    total_pages: number;
  };
}

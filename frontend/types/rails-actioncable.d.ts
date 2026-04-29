declare module "@rails/actioncable" {
  export interface Consumer {
    disconnect: () => void;
    subscriptions: {
      create: (
        channel: unknown,
        callbacks?: {
          connected?: () => void;
          disconnected?: () => void;
          received?: (data: unknown) => void;
          [key: string]: unknown;
        }
      ) => { unsubscribe: () => void };
    };
  }

  export function createConsumer(url?: string): Consumer;
}

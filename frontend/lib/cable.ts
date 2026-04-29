"use client";

import { createConsumer, type Consumer } from "@rails/actioncable";

import { getPublicApiUrl } from "@/lib/public-api-url";

let consumer: Consumer | null = null;

export function getCableConsumer(): Consumer {
  if (consumer) return consumer;

  const wsBase = getPublicApiUrl().replace(/^http/, "ws");
  consumer = createConsumer(`${wsBase}/cable`);
  return consumer;
}

export function disconnectCableConsumer(): void {
  consumer?.disconnect();
  consumer = null;
}

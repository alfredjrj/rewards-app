"use client";

import { createConsumer, type Consumer } from "@rails/actioncable";

let consumer: Consumer | null = null;

export function getCableConsumer(): Consumer {
  if (consumer) return consumer;

  const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "";
  const wsBase = apiUrl.replace(/^http/, "ws");
  consumer = createConsumer(`${wsBase}/cable`);
  return consumer;
}

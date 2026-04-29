"use client";

import { ReactNode } from "react";

type PageHeaderProps = {
  title: ReactNode;
  subtitle?: ReactNode;
  className?: string;
  titleClassName?: string;
  subtitleClassName?: string;
};

export default function PageHeader({
  title,
  subtitle,
  className = "mb-8",
  titleClassName = "text-3xl font-bold text-purple-900",
  subtitleClassName = "mt-2 text-sm text-purple-600",
}: PageHeaderProps) {
  return (
    <div className={className}>
      <h1 className={titleClassName}>{title}</h1>
      {subtitle ? <p className={subtitleClassName}>{subtitle}</p> : null}
    </div>
  );
}

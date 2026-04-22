"use client";

import Link from "next/link";
import { trackEvent } from "@/lib/tracking";
import { cn } from "@/lib/utils";
import type { ReactNode } from "react";

type TrackedLinkProps = {
  href: string;
  label: string;
  eventLabel?: string;
  className?: string;
  children?: ReactNode;
  external?: boolean;
};

export default function TrackedLink({
  href,
  label,
  eventLabel,
  className,
  children,
  external = true,
}: TrackedLinkProps) {
  function handleClick() {
    trackEvent({
      name: "link_click",
      metadata: {
        label: eventLabel || label,
        href,
      },
    });
  }

  const content = children ?? label;

  if (external) {
    return (
      <a
        href={href}
        onClick={handleClick}
        target="_blank"
        rel="noopener noreferrer"
        className={cn(className)}
      >
        {content}
      </a>
    );
  }

  return (
    <Link href={href} onClick={handleClick} className={cn(className)}>
      {content}
    </Link>
  );
}
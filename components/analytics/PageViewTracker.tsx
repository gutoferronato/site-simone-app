"use client";

import { useEffect } from "react";
import { trackEvent } from "@/lib/tracking";

export function PageViewTracker() {
  useEffect(() => {
    trackEvent({
      name: "page_view",
      category: "navigation",
      metadata: {
        title: document.title,
      },
    });
  }, []);

  return null;
}

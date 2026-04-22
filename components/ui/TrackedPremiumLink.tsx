"use client";

import TrackedLink from "@/components/analytics/TrackedLink";
import { cn } from "@/lib/utils";

type LinkItem = {
  label: string;
  href: string;
};

type TrackedPremiumLinkProps = {
  title: string;
  description: string;
  links: LinkItem[];
  highlight?: boolean;
};

export default function TrackedPremiumLink({
  title,
  description,
  links,
  highlight = false,
}: TrackedPremiumLinkProps) {
  return (
    <div
      className={cn(
        "group relative overflow-hidden rounded-[30px] border p-6 md:p-7",
        "backdrop-blur-xl transition-all duration-500 ease-out",
        "before:absolute before:inset-0 before:opacity-0 before:transition-opacity before:duration-500",
        "hover:-translate-y-[2px] hover:scale-[1.01]",
        highlight
          ? [
              "border-gold/35 bg-[linear-gradient(145deg,rgba(91,7,16,0.98),rgba(45,4,8,0.98))]",
              "shadow-[0_0_0_1px_rgba(243,193,93,0.08),0_18px_80px_-28px_rgba(243,193,93,0.35)]",
              "before:bg-[radial-gradient(circle_at_50%_0%,rgba(243,193,93,0.22),transparent_55%)]",
              "hover:shadow-[0_0_0_1px_rgba(243,193,93,0.14),0_26px_100px_-30px_rgba(243,193,93,0.45)]",
            ]
          : [
              "border-white/10 bg-white/[0.06]",
              "shadow-[0_18px_60px_-32px_rgba(0,0,0,0.55)]",
              "before:bg-[radial-gradient(circle_at_50%_0%,rgba(255,255,255,0.08),transparent_55%)]",
              "hover:border-white/15 hover:bg-white/[0.075] hover:shadow-[0_24px_80px_-34px_rgba(0,0,0,0.65)]",
            ]
      )}
    >
      <div className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-500 group-hover:opacity-100">
        <div
          className={cn(
            "absolute inset-0",
            highlight
              ? "bg-[radial-gradient(circle_at_center,rgba(243,193,93,0.16),transparent_62%)]"
              : "bg-[radial-gradient(circle_at_center,rgba(255,255,255,0.06),transparent_62%)]"
          )}
        />
        <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/25 to-transparent" />
      </div>

      <div className="relative z-10 flex flex-col gap-4">
        <h3
          className={cn(
            "luxury-title text-[2rem] md:text-[2.15rem] font-semibold leading-[1.05]",
            highlight ? "text-gold" : "text-[#f7e8df]"
          )}
        >
          {title}
        </h3>

        <p
          className={cn(
            "text-[15px] leading-7",
            highlight ? "text-[#f7dfc8]/95" : "text-zinc-300"
          )}
        >
          {description}
        </p>

        <div className="mt-2 flex flex-col gap-3">
          {links.map((link, index) => (
            <TrackedLink
              key={`${link.label}-${index}`}
              href={link.href}
              label={link.label}
              eventLabel={link.label}
              className={cn(
                "group/link relative overflow-hidden rounded-2xl px-5 py-3.5 text-center text-[12px] font-semibold uppercase tracking-[0.28em]",
                "transition-all duration-300 ease-out",
                "before:absolute before:inset-0 before:opacity-0 before:transition-opacity before:duration-300",
                "hover:-translate-y-[1px] active:scale-[0.99]",
                highlight
                  ? [
                      "border border-[#f1c35d]/35 bg-gold text-[#2f0a0d]",
                      "shadow-[inset_0_1px_0_rgba(255,255,255,0.35),0_10px_24px_-12px_rgba(243,193,93,0.45)]",
                      "hover:shadow-[inset_0_1px_0_rgba(255,255,255,0.42),0_18px_32px_-14px_rgba(243,193,93,0.55)]",
                      "before:bg-[linear-gradient(120deg,transparent,rgba(255,255,255,0.38),transparent)]",
                      "hover:before:animate-[shine_1.15s_ease]",
                    ]
                  : [
                      "border border-white/10 bg-white/10 text-white",
                      "shadow-[inset_0_1px_0_rgba(255,255,255,0.08)]",
                      "hover:border-white/20 hover:bg-white/15 hover:shadow-[0_16px_26px_-18px_rgba(0,0,0,0.45)]",
                      "before:bg-[linear-gradient(120deg,transparent,rgba(255,255,255,0.12),transparent)]",
                      "hover:before:animate-[shine_1.15s_ease]",
                    ]
              )}
            >
              <span className="relative z-10">{link.label}</span>
            </TrackedLink>
          ))}
        </div>
      </div>
    </div>
  );
}
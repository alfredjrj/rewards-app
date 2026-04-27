"use client";

import { Reward } from "@/services/api";

export type RewardType = Reward["reward_type"];

type RewardTypeMeta = {
  label: string;
  badgeClass: string;
  accentClass: string;
  iconClass: string;
  iconPath: string;
};

const REWARD_TYPE_META: Record<RewardType, RewardTypeMeta> = {
  vip_experience: {
    label: "VIP Experience",
    badgeClass: "bg-amber-100 text-amber-900 border border-amber-300",
    accentClass: "bg-gradient-to-br from-amber-50 to-orange-100 ring-1 ring-amber-200",
    iconClass: "text-amber-700",
    iconPath: "/icons/rewards/vip-experience.svg",
  },
  secret_menu: {
    label: "Secret Menu",
    badgeClass: "bg-fuchsia-100 text-fuchsia-900 border border-fuchsia-300",
    accentClass: "bg-gradient-to-br from-fuchsia-50 to-violet-100 ring-1 ring-fuchsia-200",
    iconClass: "text-fuchsia-700",
    iconPath: "/icons/rewards/secret-menu.svg",
  },
  free_item: {
    label: "Free Item",
    badgeClass: "bg-cyan-100 text-cyan-900 border border-cyan-300",
    accentClass: "bg-gradient-to-br from-cyan-50 to-sky-100 ring-1 ring-cyan-200",
    iconClass: "text-cyan-700",
    iconPath: "/icons/rewards/free-item.svg",
  },
};

export function getRewardTypeMeta(type: RewardType): RewardTypeMeta {
  return REWARD_TYPE_META[type];
}

type RewardTypeIconProps = {
  type: RewardType;
  sizeClassName?: string;
};

export function RewardTypeIcon({ type, sizeClassName = "h-8 w-8" }: RewardTypeIconProps) {
  const meta = getRewardTypeMeta(type);

  return (
    <img
      src={meta.iconPath}
      alt=""
      aria-hidden="true"
      className={`${sizeClassName} ${meta.iconClass}`}
    />
  );
}

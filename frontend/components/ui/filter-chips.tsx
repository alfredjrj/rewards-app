"use client";

type FilterChipOption<T extends string> = {
  label: string;
  value: T;
};

type FilterChipsProps<T extends string> = {
  options: FilterChipOption<T>[];
  isSelected: (value: T) => boolean;
  onSelect: (value: T) => void;
  groupAriaLabel?: string;
  activeClassName?: string;
  inactiveClassName?: string;
  buttonClassName?: string;
  containerClassName?: string;
  useSurface?: boolean;
  surfaceClassName?: string;
};

export default function FilterChips<T extends string>({
  options,
  isSelected,
  onSelect,
  groupAriaLabel,
  activeClassName = "bg-zinc-900 text-white border-zinc-900 shadow-sm",
  inactiveClassName = "bg-white text-zinc-700 border-zinc-200 hover:bg-zinc-50 hover:text-zinc-900 hover:border-zinc-300 shadow-sm",
  buttonClassName = "rounded-lg px-3.5 py-1.5 text-sm font-medium border transition",
  containerClassName = "flex flex-wrap gap-2",
  useSurface = true,
  surfaceClassName = "inline-block w-fit rounded-xl border border-zinc-200 bg-zinc-100/80 p-1.5",
}: FilterChipsProps<T>) {
  const chips = (
    <div className={containerClassName} role={groupAriaLabel ? "group" : undefined} aria-label={groupAriaLabel}>
      {options.map((option) => {
        const isActive = isSelected(option.value);
        return (
          <button
            key={option.label}
            type="button"
            onClick={() => onSelect(option.value)}
            aria-pressed={isActive}
            className={`${buttonClassName} ${isActive ? activeClassName : inactiveClassName}`}
          >
            {option.label}
          </button>
        );
      })}
    </div>
  );

  if (!useSurface) return chips;

  return <div className={surfaceClassName}>{chips}</div>;
}

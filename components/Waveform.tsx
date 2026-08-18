type WaveformVariant = "pulse" | "flat" | "rule";

type WaveformProps = {
  variant?: WaveformVariant;
  width?: number | string;
  label?: string;
};

const PULSE_PATH = "M0 8H50 M56 8H60 M64 8H68 M72 8H77 L81 5 L85 11 L90 2 L95 14 L100 4 L105 12 L110 6 L115 10 L120 8H126 M132 8H136 M140 8H144 M150 8H180";
const FLAT_PATH = "M0 8H50 M56 8H60 M64 8H68 M72 8H126 M132 8H136 M140 8H144 M150 8H180";
const RULE_PATH = "M0 8H180";

export default function Waveform({ variant = "pulse", width = 180, label }: WaveformProps) {
  const path = variant === "rule" ? RULE_PATH : variant === "flat" ? FLAT_PATH : PULSE_PATH;
  const height = typeof width === "number" ? width * (16 / 180) : undefined;

  return (
    <svg
      aria-hidden={label ? undefined : true}
      aria-label={label}
      focusable="false"
      role={label ? "img" : undefined}
      viewBox="0 0 180 16"
      width={width}
      height={height}
      style={{
        animation: "none",
        color: "var(--waveform-color, var(--rust))",
        display: "block",
        height: "auto",
        marginInline: "auto",
        maxWidth: "100%",
        overflow: "visible",
        transition: "none",
      }}
    >
      <path
        d={path}
        fill="none"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.25"
        vectorEffect="non-scaling-stroke"
      />
    </svg>
  );
}

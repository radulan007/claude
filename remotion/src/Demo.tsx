import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";

const ground = "#0b0f14";
const ink = "#f4f1ea";
const accent = "#ff5a1f";
const muted = "#8a94a3";

export const Demo: React.FC<{ title: string; subtitle: string }> = ({ title, subtitle }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const bar = spring({ frame: frame - 6, fps, config: { damping: 200 } });
  const titleIn = interpolate(frame, [12, 36], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const subIn = interpolate(frame, [27, 45], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const out = interpolate(frame, [durationInFrames - 15, durationInFrames - 3], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: ground, fontFamily: "Inter, DejaVu Sans, sans-serif", opacity: out }}>
      <div
        style={{
          position: "absolute",
          left: 160,
          top: 420,
          width: 12,
          height: 240,
          background: accent,
          transform: `scaleY(${bar})`,
          transformOrigin: "top center",
        }}
      />
      <h1
        style={{
          position: "absolute",
          left: 220,
          top: 400,
          margin: 0,
          fontSize: 140,
          fontWeight: 700,
          letterSpacing: "-0.04em",
          lineHeight: 1,
          color: ink,
          opacity: titleIn,
          transform: `translateX(${(1 - titleIn) * -60}px)`,
          filter: `blur(${(1 - titleIn) * 10}px)`,
        }}
      >
        {title}
      </h1>
      <p
        style={{
          position: "absolute",
          left: 224,
          top: 570,
          margin: 0,
          fontSize: 44,
          color: muted,
          opacity: subIn,
          transform: `translateY(${(1 - subIn) * 20}px)`,
        }}
      >
        {subtitle}
      </p>
    </AbsoluteFill>
  );
};

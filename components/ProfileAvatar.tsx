"use client";

import { useEffect, useState, type CSSProperties } from "react";

type ProfileAvatarProps = {
  name: string;
  url?: string | null;
  size?: number;
  className?: string;
  style?: CSSProperties;
  imageStyle?: CSSProperties;
};

export default function ProfileAvatar({
  name,
  url,
  size = 32,
  className,
  style,
  imageStyle,
}: ProfileAvatarProps) {
  const [imageFailed, setImageFailed] = useState(false);

  useEffect(() => {
    setImageFailed(false);
  }, [url]);

  const sharedStyle: CSSProperties = {
    width: size,
    height: size,
    borderRadius: "50%",
    flexShrink: 0,
    ...style,
  };

  if (url && !imageFailed) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={url}
        alt={name}
        className={className}
        onError={() => setImageFailed(true)}
        style={{ ...sharedStyle, objectFit: "cover", display: "block", ...imageStyle }}
      />
    );
  }

  const initial = name.trim().charAt(0).toUpperCase() || "?";
  return (
    <div
      className={className}
      role="img"
      aria-label={name}
      style={{
        ...sharedStyle,
        background: "var(--rust)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        color: "white",
        fontSize: size * 0.4,
        fontWeight: 700,
      }}
    >
      {initial}
    </div>
  );
}

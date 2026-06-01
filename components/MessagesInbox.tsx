"use client";

import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Conversation = {
  id: string;
  last_message_at: string;
  last_message_body: string | null;
  buyer_profile_id: string;
  seller_profile_id: string;
  other: { id: string; handle: string; display_name: string; avatar_url: string | null };
  listing: { id: string; title: string; images: string[] } | null;
};

type Message = {
  id: string;
  body: string;
  sender_profile_id: string;
  created_at: string;
};

function timeAgo(iso: string) {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60) return "now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
  return new Date(iso).toLocaleDateString("en", { month: "short", day: "numeric" });
}

function formatTime(iso: string) {
  const d = new Date(iso);
  const now = new Date();
  if (d.toDateString() === now.toDateString())
    return d.toLocaleTimeString("en", { hour: "2-digit", minute: "2-digit" });
  return d.toLocaleDateString("en", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

function Avatar({ name, url, size = 38 }: { name: string; url: string | null; size?: number }) {
  if (url) return <img src={url} alt={name} style={{ width: size, height: size, borderRadius: "50%", objectFit: "cover", flexShrink: 0 }} />;
  return (
    <div style={{ width: size, height: size, borderRadius: "50%", background: "var(--rust)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: size * 0.38, fontWeight: 700, color: "white", flexShrink: 0 }}>
      {name.charAt(0).toUpperCase()}
    </div>
  );
}

export default function MessagesInbox({ myProfileId }: { myProfileId: string | null }) {
  const messagesContainerRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [loadingThread, setLoadingThread] = useState(false);
  const [body, setBody] = useState("");
  const [sending, setSending] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<string | null>(null);
  const [isMobile, setIsMobile] = useState(false);

  const activeConv = conversations.find((c) => c.id === activeId) ?? null;

  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < 640);
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, []);

  useEffect(() => {
    if (!myProfileId) return;
    const supabase = createClient();
    supabase.from("conversations")
      .select(`id, last_message_at, last_message_body, buyer_profile_id, seller_profile_id,
        listing:listings(id, title, images),
        buyer:profiles!conversations_buyer_profile_id_fkey(id, handle, display_name, avatar_url),
        seller:profiles!conversations_seller_profile_id_fkey(id, handle, display_name, avatar_url)`)
      .or(`buyer_profile_id.eq.${myProfileId},seller_profile_id.eq.${myProfileId}`)
      .order("last_message_at", { ascending: false })
      .then(({ data }) => {
        if (data) setConversations(data.map((c: any) => ({
          id: c.id, last_message_at: c.last_message_at, last_message_body: c.last_message_body,
          buyer_profile_id: c.buyer_profile_id, seller_profile_id: c.seller_profile_id,
          other: c.buyer_profile_id === myProfileId ? c.seller : c.buyer,
          listing: c.listing,
        })));
        setLoading(false);
      });
  }, [myProfileId]);

  useEffect(() => {
    if (!activeId) { setMessages([]); return; }
    setLoadingThread(true);
    const supabase = createClient();
    supabase.from("messages").select("id, body, sender_profile_id, created_at")
      .eq("conversation_id", activeId).order("created_at", { ascending: true })
      .then(({ data }) => { setMessages(data ?? []); setLoadingThread(false); });

    const channel = supabase.channel(`inbox:${activeId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages", filter: `conversation_id=eq.${activeId}` },
        (payload) => setMessages((prev) => [...prev, payload.new as Message]))
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [activeId]);

  useEffect(() => {
    const el = messagesContainerRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [messages]);

  const sendMessage = async () => {
    const trimmed = body.trim();
    if (!trimmed || sending || !myProfileId || !activeId) return;
    setSending(true); setBody("");
    const supabase = createClient();
    await supabase.from("messages").insert({ conversation_id: activeId, sender_profile_id: myProfileId, body: trimmed });
    setSending(false);
    inputRef.current?.focus();
  };

  const deleteConv = async (id: string) => {
    setDeleting(id);
    const supabase = createClient();
    await supabase.from("conversations").delete().eq("id", id);
    setConversations((cs) => cs.filter((c) => c.id !== id));
    if (activeId === id) setActiveId(null);
    setConfirmDelete(null); setDeleting(null);
  };

  if (!myProfileId) return null;

  // Shared thread content (inline JSX — NOT a nested component, so textarea is never remounted)
  const threadHeader = activeConv && (
    <div style={{ padding: "0 20px", borderBottom: "1px solid var(--sand)", background: "var(--white)", flexShrink: 0 }}>
      <div style={{ height: "56px", display: "flex", alignItems: "center", gap: "10px" }}>
        {isMobile && (
          <button onClick={() => setActiveId(null)} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--text-light)", padding: "0 8px 0 0", display: "flex", alignItems: "center" }}>
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M12.5 5L7.5 10L12.5 15" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg>
          </button>
        )}
        <Avatar name={activeConv.other.display_name || activeConv.other.handle} url={activeConv.other.avatar_url} size={32} />
        <div style={{ flex: 1 }}>
          <Link href={`/${activeConv.other.handle}`} style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", textDecoration: "none" }}>{activeConv.other.display_name}</Link>
          {activeConv.listing && <Link href={`/listing/${activeConv.listing.id}`} style={{ fontSize: "12px", color: "var(--rust)", textDecoration: "none", display: "block" }}>Re: {activeConv.listing.title}</Link>}
        </div>
        {activeConv.listing?.images?.[0] && <Link href={`/listing/${activeConv.listing.id}`}><img src={activeConv.listing.images[0]} alt="" style={{ width: 34, height: 34, borderRadius: "5px", objectFit: "cover", border: "1px solid var(--sand)" }} /></Link>}
        {isMobile && (
          <button onClick={() => setActiveId(null)} style={{ background: "none", border: "1px solid var(--sand)", borderRadius: "50%", width: "28px", height: "28px", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", color: "var(--text-light)", fontSize: "16px" }}>×</button>
        )}
      </div>
    </div>
  );

  const threadMessages = (
    <div ref={messagesContainerRef} style={{ flex: 1, overflowY: "auto", padding: "16px 20px" }}>
      {loadingThread && <div style={{ display: "flex", justifyContent: "center", padding: "24px 0" }}><svg width="18" height="18" viewBox="0 0 18 18" fill="none" style={{ animation: "spin 0.8s linear infinite" }}><circle cx="9" cy="9" r="7" stroke="var(--sand)" strokeWidth="2" strokeDasharray="20 18" /></svg></div>}
      {!loadingThread && messages.length === 0 && <p style={{ textAlign: "center", fontSize: "13px", color: "var(--text-light)", padding: "24px 0" }}>Send a message to start the conversation.</p>}
      <div style={{ display: "flex", flexDirection: "column", gap: "3px" }}>
        {messages.map((msg, i) => {
          const isMe = msg.sender_profile_id === myProfileId;
          const nextSame = i < messages.length - 1 && messages[i + 1].sender_profile_id === msg.sender_profile_id;
          const prevSame = i > 0 && messages[i - 1].sender_profile_id === msg.sender_profile_id;
          return (
            <div key={msg.id} style={{ display: "flex", flexDirection: "column", alignItems: isMe ? "flex-end" : "flex-start", marginTop: prevSame ? 0 : "10px" }}>
              <div style={{ maxWidth: "70%", padding: "9px 13px", borderRadius: isMe ? `16px 16px ${nextSame ? "16px" : "3px"} 16px` : `16px 16px 16px ${nextSame ? "16px" : "3px"}`, background: isMe ? "var(--rust)" : "var(--cream)", border: isMe ? "none" : "1px solid var(--sand)", color: isMe ? "white" : "var(--text)", fontSize: "14px", lineHeight: 1.45, wordBreak: "break-word" }}>
                {msg.body}
              </div>
              {!nextSame && <span style={{ fontSize: "10px", color: "var(--text-light)", marginTop: "2px", padding: "0 3px" }}>{formatTime(msg.created_at)}</span>}
            </div>
          );
        })}
      </div>
    </div>
  );

  const threadInput = (
    <div style={{ borderTop: "1px solid var(--sand)", background: "var(--white)", padding: "10px 16px", paddingBottom: isMobile ? "max(10px, env(safe-area-inset-bottom))" : "10px", flexShrink: 0 }}>
      <div style={{ display: "flex", gap: "8px", alignItems: "flex-end" }}>
        <textarea
          ref={inputRef} value={body} onChange={(e) => setBody(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); sendMessage(); } }}
          placeholder="Type a message…" rows={1}
          style={{ flex: 1, background: "var(--cream)", border: "1.5px solid var(--sand)", borderRadius: "16px", padding: "8px 14px", fontSize: "16px", color: "var(--text)", fontFamily: "Manrope, var(--font-manrope)", outline: "none", resize: "none", maxHeight: "100px", lineHeight: 1.4, overflowY: "auto" }}
          onFocus={(e) => (e.currentTarget.style.borderColor = "var(--dark)")}
          onBlur={(e) => (e.currentTarget.style.borderColor = "var(--sand)")}
          onInput={(e) => { const t = e.currentTarget; t.style.height = "auto"; t.style.height = Math.min(t.scrollHeight, 100) + "px"; }}
        />
        <button
          onMouseDown={(e) => e.preventDefault()}
          onClick={sendMessage}
          disabled={!body.trim() || sending}
          style={{ width: "36px", height: "36px", borderRadius: "50%", background: body.trim() && !sending ? "var(--rust)" : "var(--sand)", border: "none", cursor: body.trim() && !sending ? "pointer" : "default", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
          <svg width="14" height="14" viewBox="0 0 18 18" fill="none"><path d="M16 2L8.5 9.5M16 2L11 16L8.5 9.5M16 2L2 7L8.5 9.5" stroke="white" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>
        </button>
      </div>
    </div>
  );

  const convList = (
    <div style={{ width: isMobile ? "100%" : "300px", flexShrink: 0, borderRight: isMobile ? "none" : "1px solid var(--sand)", display: "flex", flexDirection: "column" }}>
      <div style={{ padding: "16px 16px 12px", borderBottom: "1px solid var(--sand)" }}>
        <p style={{ fontSize: "13px", fontWeight: 600, color: "var(--text-mid)", margin: 0, textTransform: "uppercase", letterSpacing: "0.04em" }}>Messages</p>
      </div>
      <div style={{ flex: 1, overflowY: "auto" }}>
        {loading && <div style={{ display: "flex", justifyContent: "center", padding: "32px 0" }}><svg width="18" height="18" viewBox="0 0 18 18" fill="none" style={{ animation: "spin 0.8s linear infinite" }}><circle cx="9" cy="9" r="7" stroke="var(--sand)" strokeWidth="2" strokeDasharray="20 18" /></svg></div>}
        {!loading && conversations.length === 0 && (
          <div style={{ padding: "32px 16px", textAlign: "center" }}>
            <p style={{ fontSize: "13px", color: "var(--text-light)", marginBottom: "12px" }}>No conversations yet.</p>
            <Link href="/browse" style={{ fontSize: "13px", color: "var(--rust)", fontWeight: 600, textDecoration: "none" }}>Browse listings →</Link>
          </div>
        )}
        {conversations.map((conv) => (
          <div key={conv.id}>
            <button
              onClick={() => { setConfirmDelete(null); setActiveId(conv.id); }}
              style={{ width: "100%", display: "flex", alignItems: "center", gap: "10px", padding: "12px 14px", background: activeId === conv.id ? "oklch(94% 0.03 76)" : "transparent", border: "none", borderBottom: "1px solid var(--sand)", cursor: "pointer", textAlign: "left", borderLeft: activeId === conv.id ? "3px solid var(--rust)" : "3px solid transparent", transition: "background 0.12s" }}
              onMouseEnter={(e) => { if (activeId !== conv.id) e.currentTarget.style.background = "oklch(97% 0.01 76)"; }}
              onMouseLeave={(e) => { if (activeId !== conv.id) e.currentTarget.style.background = "transparent"; }}
            >
              <Avatar name={conv.other?.display_name || conv.other?.handle || "?"} url={conv.other?.avatar_url ?? null} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "2px" }}>
                  <span style={{ fontSize: "13px", fontWeight: 600, color: "var(--text)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", maxWidth: "120px" }}>{conv.other?.display_name || conv.other?.handle}</span>
                  <span style={{ fontSize: "11px", color: "var(--text-light)", flexShrink: 0 }}>{timeAgo(conv.last_message_at)}</span>
                </div>
                {conv.listing && <span style={{ fontSize: "11px", color: "var(--rust)", fontWeight: 500, display: "block", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>Re: {conv.listing.title}</span>}
                <p style={{ fontSize: "12px", color: "var(--text-light)", margin: 0, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{conv.last_message_body ?? "Start the conversation"}</p>
              </div>
              <button onClick={(e) => { e.stopPropagation(); setConfirmDelete(conv.id); }} style={{ width: "22px", height: "22px", borderRadius: "4px", background: "none", border: "none", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", opacity: 0, flexShrink: 0, transition: "opacity 0.15s" }} className="inbox-delete-btn" title="Delete">
                <svg width="11" height="12" viewBox="0 0 12 13" fill="none"><path d="M1 3h10M4 3V2h4v1M2 3l1 9h6l1-9" stroke="#c0392b" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" /></svg>
              </button>
            </button>
            {confirmDelete === conv.id && (
              <div style={{ display: "flex", gap: "6px", padding: "8px 14px", borderBottom: "1px solid var(--sand)", background: "oklch(98% 0.01 20)", alignItems: "center" }}>
                <span style={{ fontSize: "12px", color: "var(--text-mid)", flex: 1 }}>Delete?</span>
                <button onClick={() => deleteConv(conv.id)} style={{ fontSize: "11px", fontWeight: 700, color: "white", background: "#c0392b", border: "none", borderRadius: "4px", padding: "4px 8px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}>{deleting === conv.id ? "…" : "Delete"}</button>
                <button onClick={() => setConfirmDelete(null)} style={{ fontSize: "11px", color: "var(--text-mid)", background: "var(--white)", border: "1px solid var(--sand)", borderRadius: "4px", padding: "4px 8px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}>Cancel</button>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );

  return (
    <>
      {/* Mobile: full-screen thread overlay (NOT a separate component — inline JSX) */}
      {isMobile && activeConv && (
        <div style={{ position: "fixed", inset: 0, zIndex: 9999, background: "var(--cream)", display: "flex", flexDirection: "column" }}>
          {threadHeader}
          {threadMessages}
          {threadInput}
        </div>
      )}

      <div style={{ display: "flex", border: "1px solid var(--sand)", borderRadius: "12px", overflow: "hidden", margin: "24px 0", height: isMobile ? "auto" : "600px", background: "var(--white)" }}>
        {convList}

        {/* Desktop right panel */}
        {!isMobile && (
          activeConv ? (
            <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
              {threadHeader}
              {threadMessages}
              {threadInput}
            </div>
          ) : (
            <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", color: "var(--text-light)", gap: "10px" }}>
              <svg width="40" height="40" viewBox="0 0 24 24" fill="none"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z" stroke="var(--sand)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg>
              <p style={{ fontSize: "13px" }}>Select a conversation</p>
            </div>
          )
        )}
      </div>

      <style>{`
        @keyframes spin { to { transform: rotate(360deg); } }
        button:hover .inbox-delete-btn, div:hover > button.inbox-delete-btn { opacity: 1 !important; }
      `}</style>
    </>
  );
}

import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const read = (path: string) => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");

const homepage = read("app/page.tsx");
const authModal = read("components/AuthModal.tsx");
const loginPage = read("app/login/page.tsx");
const signupPage = read("app/signup/page.tsx");
const forgotPasswordPage = read("app/forgot-password/page.tsx");
const recoveryPage = read("app/auth/recovery/page.tsx");
const festivalPage = read("app/festivals/[slug]/page.tsx");
const handover = read("docs/DECISIONS_HANDOVER.md");

test("community spotlight only selects profiles with active listings", () => {
  assert.match(homepage, /profiles[\s\S]*?listings!inner\(id\)/);
  assert.match(homepage, /\.eq\("listings\.status", "active"\)/);
  assert.doesNotMatch(homepage, /itemCount: countMap\[row\.id\] \?\? 0/);
});

test("every login and signup form uses app-owned validation and login consent copy", () => {
  const modalLogin = authModal.slice(
    authModal.indexOf("function LoginForm"),
    authModal.indexOf("/* ── Signup form ── */")
  );
  const modalSignup = authModal.slice(
    authModal.indexOf("function SignupForm"),
    authModal.indexOf("/* ── Modal ── */")
  );

  assert.match(modalLogin, /<form noValidate onSubmit=\{handleSubmit\}/);
  assert.match(modalLogin, /By logging in you agree to our/);
  assert.match(modalLogin, /href="\/terms-of-service"/);
  assert.match(modalLogin, /href="\/privacy-policy"/);
  assert.match(modalSignup, /<form noValidate/g);
  assert.match(loginPage, /<form noValidate onSubmit=\{handleSubmit\}/);
  assert.match(signupPage, /<form noValidate/g);
  assert.match(forgotPasswordPage, /<form noValidate onSubmit=\{handleSubmit\}/);
  for (const source of [modalLogin, modalSignup, loginPage, signupPage, forgotPasswordPage]) {
    assert.match(source, /isValidEmail\(email\)/);
    assert.doesNotMatch(source, /email\.includes\("@"\)/);
  }
});

test("both signup variants flag an empty confirmation and clear stale handle availability", () => {
  for (const source of [authModal, signupPage]) {
    assert.match(source, /if \(!confirmPassword\) e\.confirmPassword = "Confirm password is required"/);
    assert.match(source, /setCheckingHandle\(true\);\s*setHandle/);
    assert.match(source, /getHandleEditValue\(handle, v\)/);
    assert.match(source, /checkHandleAvailability\(async \(\) =>/);
    assert.match(source, /hint=\{checkingHandle \? "Checking…"/);
  }
});

test("recovery copy is vendor-neutral and password fields expose guidance and visibility toggles", () => {
  const recoveryWithoutComments = recoveryPage.replace(/\/\/.*$/gm, "");
  assert.doesNotMatch(recoveryWithoutComments, /Supabase/);
  assert.match(recoveryPage, /The one-time link will not be verified until you continue and submit your new password\./);
  assert.match(recoveryPage, /Min\. 8 characters/);
  assert.match(recoveryPage, /aria-label=\{showPassword \? "Hide new password" : "Show new password"\}/);
  assert.match(recoveryPage, /aria-label=\{showConfirmPassword \? "Hide confirm password" : "Show confirm password"\}/);
  assert.match(recoveryPage, /htmlFor="new-password"/);
  assert.match(recoveryPage, /aria-describedby="new-password-message"/);
  assert.match(recoveryPage, /htmlFor="confirm-password"/);
  assert.match(recoveryPage, /aria-describedby=\{fieldErrors\.confirmPassword/);
  assert.match(recoveryPage, /minWidth: "32px"/);
  assert.match(recoveryPage, /<form noValidate onSubmit=\{updatePassword\}/);
});

test("festival RSVP change and remove controls have a visible interactive treatment", () => {
  const rsvpControls = festivalPage.slice(
    festivalPage.indexOf("{myRsvp ? ("),
    festivalPage.indexOf(") : (", festivalPage.indexOf("{myRsvp ? ("))
  );

  assert.match(rsvpControls, /color: "oklch\(92% 0\.01 80\)"/);
  assert.match(rsvpControls, /background: "oklch\(100% 0 0 \/ 0\.08\)"/);
  assert.match(rsvpControls, /border: "1px solid oklch\(100% 0 0 \/ 0\.18\)"/);
  assert.match(rsvpControls, />\s*Change\s*<\/button>/);
  assert.match(rsvpControls, />\s*Remove\s*<\/button>/);
});

test("festival wall user-facing copy is renamed to Notice Board", () => {
  assert.match(festivalPage, />Notice Board<\/h2>/);
  assert.match(festivalPage, /label: "Notice Board"/);
  assert.match(festivalPage, /placeholder="Search the notice board…"/);
  assert.match(festivalPage, /"Nothing on the notice board matches your search\."/);
  assert.doesNotMatch(festivalPage, />The Wall<\/h2>/);
  assert.doesNotMatch(festivalPage, /label: "The Wall"/);
});

test("festival notice deletion uses an isolated per-note confirmation and error flow", () => {
  const deleteControl = festivalPage.slice(
    festivalPage.indexOf("function NoticeDeleteControl"),
    festivalPage.indexOf("function NoticeBoardTab")
  );

  assert.match(deleteControl, /const \[confirmDelete, setConfirmDelete\] = useState\(false\)/);
  assert.match(deleteControl, /const \[deleting, setDeleting\] = useState\(false\)/);
  assert.match(deleteControl, /<span>Delete permanently\?<\/span>/);
  assert.match(deleteControl, /deleting \? "Deleting…" : "Yes, delete"/);
  assert.match(deleteControl, />Keep<\/button>/);
  assert.match(deleteControl, /disabled=\{deleting\}/);
  assert.match(deleteControl, /deleteError && <p role="alert"/);
  assert.match(festivalPage, /<NoticeDeleteControl postId=\{post\.id\} onDeleted=\{fetchPosts\} \/>/);
  assert.doesNotMatch(festivalPage, /confirmDeleteId|deletingId/);
  assert.doesNotMatch(festivalPage, /onClick=\{\(\) => deletePost\(post\.id\)\} title="Remove note"/);
});

test("legacy reset-password route preserves query and hash when forwarding", () => {
  const resetPasswordPath = new URL("../app/reset-password/page.tsx", import.meta.url);
  assert.equal(existsSync(resetPasswordPath), true);
  const resetPasswordPage = readFileSync(resetPasswordPath, "utf8");

  assert.match(resetPasswordPage, /router\.replace\(`\/update-password\$\{window\.location\.search\}\$\{window\.location\.hash\}`\)/);
});

test("QA handover keeps credential entry and submission with Turgay", () => {
  assert.match(
    handover,
    /The QA tester never performs the four credential moments—signup submit, either login, or password entry; those stay with Turgay\./
  );
});

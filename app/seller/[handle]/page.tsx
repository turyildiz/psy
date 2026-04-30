import { redirect } from "next/navigation";

export default function SellerRedirect({ params }: { params: { handle: string } }) {
  redirect(`/${params.handle}`);
}

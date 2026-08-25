"use client";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { auth } from "@/firebase";
import { DEV_AUTH_ENABLED } from "@/lib/devAuth";
import { useCurrentUser } from "@/lib/useCurrentUser";
import { signOut } from "firebase/auth";
import { Dna } from "lucide-react";
import { Link, useNavigate } from "react-router-dom";

export function Navbar() {
	const user = useCurrentUser();
	const navigate = useNavigate();

	const handleLogout = async () => {
		try {
			await signOut(auth);
			navigate("/login");
		} catch (error) {
			console.error("Error signing out:", error);
		}
	};

	return (
		<header className="sticky top-0 z-50 w-full border-b border-border/60 bg-background/95 backdrop-blur">
			<div className="mx-auto flex min-h-16 w-full max-w-screen-2xl items-center justify-between px-4">
				<Link
					to="/"
					className="flex items-center gap-2"
					aria-label="seAMLess dashboard"
				>
					<span className="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-900 text-white">
						<Dna size={20} aria-hidden="true" />
					</span>
					<span className="text-lg font-black tracking-tight">seAMLess</span>
				</Link>

				{user && (
					<div className="flex items-center gap-3">
						<div className="hidden items-center gap-2 text-sm text-muted-foreground sm:flex">
							<Avatar className="h-8 w-8">
								<AvatarImage src={user.photoURL || ""} />
								<AvatarFallback>
									{user.email?.[0]?.toUpperCase() ?? "S"}
								</AvatarFallback>
							</Avatar>
							<span>{user.email}</span>
						</div>
						{!DEV_AUTH_ENABLED && (
							<Button variant="outline" size="sm" onClick={handleLogout}>
								Sign out
							</Button>
						)}
					</div>
				)}
			</div>
		</header>
	);
}

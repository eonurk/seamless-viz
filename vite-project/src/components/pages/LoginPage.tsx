import Login from "@/components/Login";
import { Navbar } from "@/components/header/Navbar";
import { useNavigate } from "react-router-dom";
import { useEffect } from "react";
import { User as FirebaseUser } from "firebase/auth";

export function LoginPage({ user }: { user: FirebaseUser | null }) {
	const navigate = useNavigate();

	useEffect(() => {
		if (user) {
			navigate("/");
		}
	}, [user, navigate]);

	return (
		<>
			<Navbar />
			<div className="min-h-screen flex flex-col">
				{!user && (
					<main className="flex-1 flex items-center justify-center">
						<div className="text-2xl font-normal text-neutral-600 dark:text-neutral-400">
							<Login />
						</div>
					</main>
				)}
			</div>
		</>
	);
}

export default LoginPage;

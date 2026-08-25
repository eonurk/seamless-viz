// reset password page

import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { sendPasswordResetEmail } from "firebase/auth";
import { auth } from "@/firebase";
import { Navbar } from "@/components/header/Navbar";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";

export function ResetPassword() {
	const [email, setEmail] = useState("");
	const [error, setError] = useState("");
	const [message, setMessage] = useState("");

	const navigate = useNavigate();

	const handleResetPassword = async (e: React.FormEvent) => {
		e.preventDefault();
		try {
			await sendPasswordResetEmail(auth, email);
			setMessage("Password reset email sent. Check your inbox.");
			setTimeout(() => navigate("/login"), 3000); // Redirect to login page after 3 seconds
		} catch (error: unknown) {
			setError(
				error instanceof Error ? error.message : "Failed to reset password"
			);
			console.error("Password reset error:", error);
		}
	};

	return (
		<>
			<Navbar />
			<div className="flex justify-center items-center h-screen">
				<div className="w-full max-w-md p-8 bg-white rounded-lg shadow-md">
					<h2 className="text-2xl font-bold mb-6">Reset Password</h2>
					<form onSubmit={handleResetPassword} className="space-y-4">
						<div>
							<Label
								htmlFor="email"
								className="block text-sm font-medium text-gray-700"
							>
								Email
							</Label>
							<Input
								type="email"
								id="email"
								placeholder="your@email.com"
								value={email}
								onChange={(e) => setEmail(e.target.value)}
								required
							/>
						</div>
						{error && <p className="text-red-500 text-sm">{error}</p>}
						{message && <p className="text-green-500 text-sm">{message}</p>}
						<Button type="submit">Reset Password</Button>
					</form>
				</div>
			</div>
		</>
	);
}

export default ResetPassword;

import "./App.css";
import { Dashboard } from "@/components/pages/Dashboard";
import { Toaster } from "@/components/ui/toaster";
import { useState, useEffect } from "react";
import {
	User as FirebaseUser,
	onAuthStateChanged,
	getAuth,
} from "firebase/auth";
import {
	BrowserRouter as Router,
	Navigate,
	Route,
	Routes,
} from "react-router-dom";

import LoginPage from "@/components/pages/LoginPage";
import "@/firebase";
import { DEV_AUTH_ENABLED, DEV_USER } from "@/lib/devAuth";
import ResetPassword from "@/components/pages/ResetPassword";

function App() {
	const [user, setUser] = useState<FirebaseUser | null>(
		DEV_AUTH_ENABLED ? DEV_USER : null,
	);
	const auth = getAuth();

	useEffect(() => {
		// The dev bypass has no Firebase session to observe.
		if (DEV_AUTH_ENABLED) return;
		const unsubscribe = onAuthStateChanged(auth, (user) => {
			setUser(user);
		});
		return () => unsubscribe(); // Cleanup on unmount
	}, [auth]);

	return (
		<>
			<Toaster />

			<Router>
				<Routes>
					<Route path="/" element={<Dashboard user={user} />} />
					<Route path="/dashboard" element={<Dashboard user={user} />} />
					<Route path="/login" element={<LoginPage user={user} />} />
					<Route path="/reset-password" element={<ResetPassword />} />
					<Route path="*" element={<Navigate to="/" replace />} />
				</Routes>
			</Router>
		</>
	);
}

export default App;

import { auth } from "@/firebase";
import axiosLib, { isAxiosError } from "axios";

import { DEV_AUTH_ENABLED, DEV_ID_TOKEN } from "@/lib/devAuth";

// VITE_API_BASE_URL wins when set (needed when the stack is reached over
// anything other than localhost, e.g. a Docker host on the LAN).
const API_BASE_URL =
	import.meta.env.VITE_API_BASE_URL ||
	(window.location.hostname === "localhost"
		? "http://localhost:3001/v1"
		: "/api/v1");

const axios = axiosLib.create();
export const DASHBOARD_DISEASE_STORAGE_KEY = "seamless-dashboard-disease";
const READS_PER_GENE_FILE_REGEX = /readspergene\.out(?: ?\(\d+\))?\.tab$/i;

export type DiseaseId = "aml" | "ball" | "tall" | "pan_leukemia";
export type ReferenceDiseaseId = "aml" | "ball" | "tall";
export type MolecularToolId =
	| "bridge"
	| "amlmapr"
	| "allcatchr"
	| "allsorts"
	| "tallsorts";
export type MolecularToolAvailability = {
	available?: boolean;
	runtime_ready?: boolean;
	catalog_only?: boolean;
	missing?: string[];
	artifact_source?: string;
};
export type MolecularToolCatalogEntry = {
	id: string;
	label: string;
	short_label?: string;
	family?: string;
	integrated?: boolean;
	endpoint?: string;
	disease_scope?: DiseaseId | ReferenceDiseaseId;
	supported_diseases?: Array<DiseaseId | ReferenceDiseaseId>;
	applicable_for_request?: boolean;
	input_modality?: string;
	gene_identifier?: string;
	output_kind?: string;
	confidence_semantics?: string;
	repo_url?: string;
	docs_url?: string;
	notes?: string;
	availability?: MolecularToolAvailability;
};

function normalizeReferenceDiseases(
	values?: string[] | null,
): ReferenceDiseaseId[] {
	const allowed: ReferenceDiseaseId[] = ["aml", "ball", "tall"];
	const set = new Set<ReferenceDiseaseId>();
	for (const value of values ?? []) {
		if (value === "aml" || value === "ball" || value === "tall") {
			set.add(value);
		}
		if (value === "pan_leukemia") {
			allowed.forEach((d) => set.add(d));
		}
	}
	const normalized = allowed.filter((d) => set.has(d));
	return normalized.length > 0 ? normalized : ["aml"];
}

export function getSelectedReferenceDiseases(): ReferenceDiseaseId[] {
	if (typeof window === "undefined") return ["aml"];
	const raw = window.localStorage.getItem(DASHBOARD_DISEASE_STORAGE_KEY);
	if (!raw) return ["aml"];
	try {
		const parsed = JSON.parse(raw);
		if (Array.isArray(parsed)) {
			return normalizeReferenceDiseases(parsed.map(String));
		}
	} catch {
		// Backward compatibility with legacy single-value storage.
	}
	return normalizeReferenceDiseases([raw]);
}

export function getSelectedDiseaseContext(): DiseaseId {
	return deriveDiseaseParam(getSelectedReferenceDiseases());
}

function deriveDiseaseParam(diseases: ReferenceDiseaseId[]): DiseaseId {
	if (diseases.length > 1) return "pan_leukemia";
	return diseases[0] ?? "aml";
}

function withDiseaseParam<T extends Record<string, unknown>>(
	params?: T,
	disease?: DiseaseId | ReferenceDiseaseId[],
) {
	const selectedDiseases = Array.isArray(disease)
		? normalizeReferenceDiseases(disease)
		: normalizeReferenceDiseases(
				disease ? [disease] : getSelectedReferenceDiseases(),
		  );

	return {
		...(params ?? {}),
		disease: deriveDiseaseParam(selectedDiseases),
		diseases: selectedDiseases.join(","),
	};
}

axios.interceptors.request.use(async (config) => {
	const token = DEV_AUTH_ENABLED
		? DEV_ID_TOKEN
		: await auth.currentUser?.getIdToken();
	config.headers["Authorization"] = `Bearer ${token}`;
	return config;
});

export async function fetchTSNEData(disease?: DiseaseId | ReferenceDiseaseId[]) {
	try {
		const response = await axios.get(`${API_BASE_URL}/tsne`, {
			params: withDiseaseParam(undefined, disease),
		});
		return response.data;
	} catch (error) {
		console.error("Error fetching TSNE data:", error);
		throw error;
	}
}

export async function fetchDeconvolutionData(
	samples?: string[],
	includeReference = false,
) {
	try {
		const response = await axios.get(`${API_BASE_URL}/deconvolution`, {
			params: withDiseaseParam({
				samples: samples && samples.length > 0 ? samples.join(",") : undefined,
				include_reference: includeReference,
			}),
		});
		return response.data;
	} catch (error) {
		console.error("Error fetching deconvolution data:", error);
		throw error;
	}
}

export async function fetchDrugResponseData() {
	try {
		const response = await axios.get(`${API_BASE_URL}/drug-response`);
		return response.data;
	} catch (error) {
		console.error("Error fetching deconvolution data:", error);
		throw error;
	}
}

export async function fetchMutationTSNEData() {
	try {
		const response = await axios.get(`${API_BASE_URL}/mutation-tsne`);
		return response.data;
	} catch (error) {
		console.error("Error fetching mutation t-SNE data:", error);
		throw error;
	}
}

export async function fetchAberrationsTSNEData() {
	try {
		const response = await axios.get(`${API_BASE_URL}/aberrations-tsne`);
		return response.data;
	} catch (error) {
		console.error("Error fetching aberrations t-SNE data:", error);
		throw error;
	}
}

export async function uploadSampleData(files: File[]) {
	if (files.length === 0) {
		throw new Error("Please select a file to upload");
	}

	const isCsvUpload =
		files.length === 1 && files[0].name.toLowerCase().endsWith(".csv");
	const isReadsPerGeneUpload = files.every((file) =>
		READS_PER_GENE_FILE_REGEX.test(file.name)
	);

	if (!isCsvUpload && !isReadsPerGeneUpload) {
		throw new Error(
			"Please upload a single CSV or one or more ReadsPerGene.out.tab files (including copied names like ReadsPerGene.out(1).tab)"
		);
	}

	const formData = new FormData();
	files.forEach((file) => {
		formData.append("files", file, file.name);
	});

	// Improved logging for FormData
	for (const pair of formData.entries()) {
		console.log(`${pair[0]}:`, pair[1]);
	}

	try {
		const response = await axios.post(
			`${API_BASE_URL}/load-sample-data`,
			formData,
			{
				// Remove manual 'Content-Type' to allow axios to set it correctly
				// headers: {
				//     "Content-Type": "multipart/form-data",
				// },
				onUploadProgress: (progressEvent) => {
					if (progressEvent.total) {
						const percentCompleted = Math.round(
							(progressEvent.loaded * 100) / progressEvent.total
						);
						console.log(`Upload progress: ${percentCompleted}%`);
					}
				},
			}
		);

		if (response.data.error) {
			throw new Error(response.data.error);
		}
		return response.data;
	} catch (error) {
		console.error("Error uploading sample data:", error);
		if (isAxiosError(error)) {
			console.error("Axios error details:", error.response?.data);
			console.error("Axios error status:", error.response?.status);
		}
		throw error;
	}
}

export async function fetchSampleDataNames() {
	const response = await axios.get(`${API_BASE_URL}/sample-data-names`);
	return response.data;
}

export async function fetchHarmonizedDataNames() {
	const response = await axios.get(`${API_BASE_URL}/harmonized-data-names`);
	return response.data;
}

export async function fetchHarmonizationManifest() {
	const response = await axios.get(`${API_BASE_URL}/harmonization-manifest`);
	return response.data;
}

export async function fetchBridgePrediction(sample: string) {
	const response = await axios.get(`${API_BASE_URL}/bridge-predict`, {
		params: withDiseaseParam({ sample }),
	});
	return response.data;
}

export async function fetchMolecularPrediction(
	tool: MolecularToolId,
	sample: string,
	disease?: DiseaseId | ReferenceDiseaseId[],
) {
	const response = await axios.get(`${API_BASE_URL}/molecular-predict`, {
		params: withDiseaseParam({ tool, sample }, disease),
	});
	return response.data;
}

export async function fetchMolecularTools(
	disease?: DiseaseId | ReferenceDiseaseId[],
): Promise<{
	request_disease?: DiseaseId;
	request_diseases?: ReferenceDiseaseId[];
	tools?: MolecularToolCatalogEntry[];
}> {
	const response = await axios.get(`${API_BASE_URL}/molecular-tools`, {
		params: withDiseaseParam(undefined, disease),
	});
	return response.data;
}

export async function fetchAMLmaprPrediction(sample: string) {
	const response = await axios.get(`${API_BASE_URL}/amlmapr-predict`, {
		params: withDiseaseParam({ sample }),
	});
	return response.data;
}

export async function fetchALLSortsPrediction(sample: string) {
	const response = await axios.get(`${API_BASE_URL}/allsorts-predict`, {
		params: withDiseaseParam({ sample }),
	});
	return response.data;
}

export async function fetchTALLSortsPrediction(sample: string) {
	const response = await axios.get(`${API_BASE_URL}/tallsorts-predict`, {
		params: withDiseaseParam({ sample }),
	});
	return response.data;
}

export interface CacheFile {
	name: string;
	size: number;
	modified: string;
	isUserUploaded: boolean;
}

export async function fetchCacheFiles(): Promise<CacheFile[]> {
	try {
		const response = await axios.get(`${API_BASE_URL}/cache-files`);
		return response.data;
	} catch (error) {
		console.error("Error fetching cache files:", error);
		throw error;
	}
}

export async function deleteCacheFile(fileName: string) {
	try {
		const response = await axios.delete(`${API_BASE_URL}/delete-cache-file`, {
			params: { fileName },
		});
		console.log("Response from deleteCacheFile:", response.data);
		return response.data;
	} catch (error) {
		console.error("Error deleting cache file:", error);
		throw error;
	}
}

export async function fetchGeneExpressionData(gene: string) {
	const response = await axios.get(`${API_BASE_URL}/gene-expression`, {
		params: { gene },
	});
	return response.data;
}

export async function fetchHarmonizedData(
	samples: string[],
	disease?: DiseaseId | ReferenceDiseaseId[],
) {
	const response = await axios.get(`${API_BASE_URL}/harmonize-data`, {
		params: withDiseaseParam({ samples }, disease),
	});
	return response.data;
}

export async function fetchKNNData(k: number) {
	const response = await axios.get(`${API_BASE_URL}/knn`, {
		params: { k },
	});
	return response.data;
}

export async function fetchAIReport(patientInfo: string, model: string) {
	const response = await axios.get(`${API_BASE_URL}/ai-report`, {
		params: { patientInfo, model },
	});
	return response.data;
}

export async function fetchQCMetrics() {
	const response = await axios.get(`${API_BASE_URL}/qc-metrics`);
	return response.data;
}

export async function fetchKNNDEG(k: number, sampleId: string) {
	const response = await axios.get(`${API_BASE_URL}/knn-deg`, {
		params: { k, sampleId },
	});
	return response.data;
}

export type DysregulationGene = {
	gene_id: string;
	target_expr: number;
	cohort_mean: number;
	delta: number;
	robust_z: number;
	percentile_rank: number;
};

export type DysregulationResult = {
	sample_requested?: string;
	sample_resolved?: string;
	warning?: string | null;
	cohort_size?: number;
	genes_tested?: number;
	summary?: {
		up_count?: number;
		down_count?: number;
		extreme_abs_z_count?: number;
	};
	top_up?: DysregulationGene[];
	top_down?: DysregulationGene[];
	error?: string;
};

export async function fetchSampleDysregulation(
	sample: string,
	topN = 50,
): Promise<DysregulationResult> {
	const response = await axios.get(`${API_BASE_URL}/sample-dysregulation`, {
		params: {
			sample,
			top_n: topN,
		},
	});
	return response.data;
}

export type GseaPathway = {
	pathway: string;
	NES: number;
	pval: number;
	padj: number;
	size: number;
	leading_edge?: string;
};

export type SampleGseaResult = {
	sample_requested?: string;
	sample_resolved?: string;
	warning?: string | null;
	collection?: string;
	cohort_size?: number;
	genes_ranked?: number;
	pathways_tested?: number;
	pathways?: GseaPathway[];
	error?: string;
	missing?: string[];
	install_hint?: string;
};

export async function fetchSampleGSEA(
	sample: string,
	collection: "hallmark" | "reactome" | "go_bp" = "hallmark",
	topN = 30,
): Promise<SampleGseaResult> {
	const response = await axios.get(`${API_BASE_URL}/sample-gsea`, {
		params: {
			sample,
			collection,
			top_n: topN,
		},
	});
	return response.data;
}

export async function fetchCNVData(
	samples?: string[],
	useUploadedNames?: boolean
) {
	const params: any = {};
	if (samples && samples.length > 0) {
		params.samples = samples.join(",");
	}
	if (useUploadedNames !== undefined) {
		params.use_uploaded_names = useUploadedNames.toString();
	}

	const response = await axios.get(`${API_BASE_URL}/genome-expression`, {
		params,
	});
	return response.data;
}

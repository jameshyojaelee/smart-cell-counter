import { NativeModules, Platform } from "react-native";

type Corner = { x: number; y: number };
type DetectResult = {
  corners: Corner[];
  gridType: "neubauer" | "disposable" | null;
  pixelsPerMicron: number | null;
  focusScore: number;
  glareRatio: number;
};

const { CellCounterModule } = NativeModules;

export async function detectGridAndCornersIOS(inputUri: string): Promise<DetectResult> {
  if (Platform.OS !== "ios") throw new Error("iOS only");
  return await CellCounterModule.detectGridAndCorners(inputUri);
}

export async function perspectiveCorrectIOS(inputUri: string, corners: Corner[]): Promise<string> {
  if (Platform.OS !== "ios") throw new Error("iOS only");
  return await CellCounterModule.perspectiveCorrect(inputUri, corners);
}

export async function runCoreMLSegmentationIOS(correctedImageUri: string): Promise<string | null> {
  if (Platform.OS !== "ios") throw new Error("iOS only");
  const uri: string | null = await CellCounterModule.runCoreMLSegmentation(correctedImageUri);
  return uri || null;
}

export function initializeScreenShare(): void;
export function createScreenShareOffer(stunTurnJson: string): void;
export function setScreenShareRemoteSDP(remoteSDP: string): void;
export function addScreenShareRemoteIceCandidate(remoteCandidateJson: string): void;
export function stopScreenShareBroadcastExtension(): void; 
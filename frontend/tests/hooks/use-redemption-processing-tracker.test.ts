import { act, renderHook, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { useRedemptionProcessingTracker } from "@/hooks/use-redemption-processing-tracker";

const unsubscribeMock = vi.fn();
let cableReceivedHandler: ((payload: unknown) => void) | undefined;
const cableCreateMock = vi.fn((_identifier: unknown, callbacks: { received?: (payload: unknown) => void }) => {
  cableReceivedHandler = callbacks?.received;
  return { unsubscribe: unsubscribeMock };
});

const readProcessingRedemptionsMock = vi.fn();
const writeProcessingRedemptionsMock = vi.fn();

vi.mock("@/lib/cable", () => ({
  getCableConsumer: () => ({
    subscriptions: {
      create: (identifier: unknown, callbacks: { received?: (payload: unknown) => void }) =>
        cableCreateMock(identifier, callbacks),
    },
  }),
}));

vi.mock("@/lib/processing-redemptions", () => ({
  readProcessingRedemptions: (...args: unknown[]) => readProcessingRedemptionsMock(...args),
  writeProcessingRedemptions: (...args: unknown[]) => writeProcessingRedemptionsMock(...args),
}));

describe("useRedemptionProcessingTracker", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    readProcessingRedemptionsMock.mockReturnValue([]);
  });

  it("adds and deduplicates processing requests", () => {
    const { result } = renderHook(() =>
      useRedemptionProcessingTracker({
        onCompleted: vi.fn(),
        onFailed: vi.fn(),
        pollStatus: vi.fn().mockResolvedValue({ request_id: "x", status: "processing" }),
      })
    );

    act(() => {
      result.current.addProcessingRequest({
        requestId: "req-1",
        rewardTitle: "Free Coffee",
        pointsSpent: 100,
      });
      result.current.addProcessingRequest({
        requestId: "req-1",
        rewardTitle: "Free Coffee",
        pointsSpent: 100,
      });
    });

    expect(result.current.processingRequests).toHaveLength(1);
    expect(result.current.processingRequestId).toBe("req-1");
  });

  it("rehydrates persisted processing requests and handles cable completion", async () => {
    readProcessingRedemptionsMock.mockReturnValue([
      { requestId: "req-1", rewardTitle: "Free Coffee", pointsSpent: 100 },
    ]);
    const onCompleted = vi.fn();
    const onFailed = vi.fn();

    renderHook(() =>
      useRedemptionProcessingTracker({
        onCompleted,
        onFailed,
        pollStatus: vi.fn().mockResolvedValue({ request_id: "req-1", status: "processing" }),
      })
    );

    await waitFor(() => {
      expect(cableCreateMock).toHaveBeenCalled();
    });

    act(() => {
      cableReceivedHandler?.({
        request_id: "req-1",
        reward_id: 1,
        status: "completed",
      });
    });

    await waitFor(() => {
      expect(onCompleted).toHaveBeenCalledWith({
        requestId: "req-1",
        processing: { requestId: "req-1", rewardTitle: "Free Coffee", pointsSpent: 100 },
      });
    });
    expect(onFailed).not.toHaveBeenCalled();
    expect(writeProcessingRedemptionsMock).toHaveBeenCalled();
  });
});

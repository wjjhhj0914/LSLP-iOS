//
//  OrderStatusDetailView.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import SwiftUI

struct OrderStatusDetailView: View {
    let order: ValidatedOrderItem
    var showsNavigationHeader: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if showsNavigationHeader {
                        header
                    }
                    instructionBanner
                    currentOrderSection
                }
                .padding(.horizontal, 16)
                .padding(.top, showsNavigationHeader ? 8 : 20)
                .padding(.bottom, 120)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.33, green: 0.38, blue: 0.30))
                    .frame(width: 40, height: 40)
                    .background(.white)
                    .clipShape(Circle())
            }

            Spacer()

            Text("주문현황")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Color(red: 0.26, green: 0.30, blue: 0.24))

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
    }

    private var instructionBanner: some View {
        Text("픽업을 하실 때는 주문번호를 꼭 말씀해주세요!")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color(red: 0.69, green: 0.76, blue: 0.62))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.95, green: 0.97, blue: 0.92))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
            )
    }

    private var currentOrderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("주문현황")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.63, green: 0.65, blue: 0.63))

            VStack(spacing: 14) {
                topCard
                menuCard
            }
        }
    }

    private var topCard: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("주문번호 \(order.orderCode)")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color(red: 0.69, green: 0.72, blue: 0.69))

                Text(order.store?.name ?? "주문 가게")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Color(red: 0.40, green: 0.49, blue: 0.36))
                    .lineLimit(2)

                Text(order.paidAt?.formattedOrderDate ?? order.createdAt?.formattedOrderDate ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.78, green: 0.79, blue: 0.79))

                Spacer(minLength: 12)

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
                        .frame(width: 126, height: 126)

                    if let url = order.store?.resolvedImageURL {
                        AuthenticatedImage(url: url)
                            .frame(width: 118, height: 118)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(Color(red: 0.77, green: 0.79, blue: 0.76))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            OrderTimelineView(entries: order.orderStatusTimeline)
                .frame(width: 128)
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var menuCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(order.orderMenuList.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.95, green: 0.97, blue: 0.95))
                            .frame(width: 88, height: 72)

                        if let url = item.menu.resolvedImageURL {
                            AuthenticatedImage(url: url)
                                .frame(width: 88, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(Color(red: 0.78, green: 0.79, blue: 0.76))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.menu.name)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(Color(red: 0.32, green: 0.35, blue: 0.31))
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Text(item.menu.price.formattedPriceText)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color(red: 0.32, green: 0.35, blue: 0.31))

                            Text("\(item.quantity)EA")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(red: 0.62, green: 0.64, blue: 0.64))
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                if index < order.orderMenuList.count - 1 {
                    Divider()
                        .padding(.horizontal, 18)
                }
            }

            Divider()
                .padding(.horizontal, 18)

            HStack {
                Text("결제금액")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.71, green: 0.72, blue: 0.71))

                Spacer()

                Text("\(order.totalCount)EA")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.71, green: 0.72, blue: 0.71))

                Text(order.totalPrice.formattedPriceText)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color(red: 0.24, green: 0.27, blue: 0.23))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct OrderTimelineView: View {
    let entries: [ValidatedOrderStatusEntry]

    private let statuses = [
        "PENDING_APPROVAL",
        "APPROVED",
        "IN_PROGRESS",
        "READY_FOR_PICKUP",
        "PICKED_UP"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(statuses, id: \.self) { status in
                let entry = entries.first { $0.status == status }
                let isCompleted = entry?.completed == true

                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle()
                            .strokeBorder(isCompleted ? Color(red: 0.56, green: 0.66, blue: 0.48) : Color(red: 0.86, green: 0.87, blue: 0.86), lineWidth: 2)
                            .background(
                                Circle()
                                    .fill(isCompleted ? Color(red: 0.56, green: 0.66, blue: 0.48) : .white)
                            )
                            .frame(width: 20, height: 20)
                            .overlay {
                                if isCompleted {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }

                        if status != statuses.last {
                            Rectangle()
                                .fill(isCompleted ? Color(red: 0.80, green: 0.85, blue: 0.76) : Color(red: 0.91, green: 0.92, blue: 0.91))
                                .frame(width: 2, height: 28)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.koreanOrderStatus)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isCompleted ? Color(red: 0.40, green: 0.49, blue: 0.36) : Color(red: 0.78, green: 0.79, blue: 0.79))

                        if let changedAt = entry?.changedAt {
                            Text(changedAt.formattedShortTime)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.72, green: 0.73, blue: 0.72))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension String {
    var koreanOrderStatus: String {
        switch self {
        case "PENDING_APPROVAL": return "승인대기"
        case "APPROVED": return "주문승인"
        case "IN_PROGRESS": return "조리 중"
        case "READY_FOR_PICKUP": return "픽업대기"
        case "PICKED_UP": return "픽업완료"
        default: return self
        }
    }

    var formattedOrderDate: String {
        guard let date = ISO8601DateFormatter().date(from: self) else { return self }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 a h:mm"
        return formatter.string(from: date)
    }

    var formattedShortTime: String {
        guard let date = ISO8601DateFormatter().date(from: self) else { return self }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
}

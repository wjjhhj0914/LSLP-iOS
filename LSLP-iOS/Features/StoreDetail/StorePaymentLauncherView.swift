//
//  StorePaymentLauncherView.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import SwiftUI
import UIKit
import iamport_ios

struct StorePaymentRequest: Identifiable, Equatable {
    let id = UUID()
    let order: CreatedOrder
    let orderName: String
    let buyerName: String
}

enum StorePaymentResult {
    case success(impUID: String, merchantUID: String)
    case failure(String)
    case cancelled
}

struct StorePaymentLauncherView: UIViewControllerRepresentable {
    let request: StorePaymentRequest
    let onComplete: (StorePaymentResult) -> Void

    func makeUIViewController(context: Context) -> StorePaymentLauncherViewController {
        let viewController = StorePaymentLauncherViewController()
        viewController.request = request
        viewController.onComplete = onComplete
        return viewController
    }

    func updateUIViewController(_ uiViewController: StorePaymentLauncherViewController, context: Context) {}
}

final class StorePaymentLauncherViewController: UIViewController {
    var request: StorePaymentRequest?
    var onComplete: ((StorePaymentResult) -> Void)?
    private var didStartPayment = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !didStartPayment else { return }
        didStartPayment = true
        startPayment()
    }

    private func startPayment() {
        guard let request else {
            onComplete?(.failure("결제 요청 정보가 없습니다."))
            return
        }

        let payment = IamportPayment(
            pg: PG.html5_inicis.makePgRawName(pgId: APIKey.PORTONE_INICIS_PG_ID),
            merchant_uid: request.order.orderCode,
            amount: String(request.order.totalPrice)
        )
        payment.pay_method = PayMethod.card.rawValue
        payment.name = request.orderName
        payment.buyer_name = request.buyerName
        payment.app_scheme = APIKey.PORTONE_APP_SCHEME

        print(
            """
            [PORTONE PAYMENT REQUEST]
            user_code: \(APIKey.PORTONE_USER_CODE)
            pg: \(PG.html5_inicis.makePgRawName(pgId: APIKey.PORTONE_INICIS_PG_ID))
            merchant_uid: \(request.order.orderCode)
            amount: \(request.order.totalPrice)
            order_name: \(request.orderName)
            app_scheme: \(APIKey.PORTONE_APP_SCHEME)
            """
        )

        Iamport.shared.payment(
            viewController: self,
            userCode: APIKey.PORTONE_USER_CODE,
            payment: payment
        ) { [weak self] response in
            self?.handlePaymentResponse(response)
        }
    }

    private func handlePaymentResponse(_ response: IamportResponse?) {
        guard let response else {
            onComplete?(.cancelled)
            return
        }

        print(
            """
            [PORTONE PAYMENT CALLBACK]
            success: \(String(describing: response.success))
            imp_uid: \(response.imp_uid ?? "nil")
            merchant_uid: \(response.merchant_uid ?? "nil")
            error_code: \(response.error_code ?? "nil")
            error_msg: \(response.error_msg ?? "nil")
            expected_order_code: \(request?.order.orderCode ?? "nil")
            """
        )

        let resolvedMerchantUID = response.merchant_uid?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if response.success == true, let impUID = response.imp_uid, !impUID.isEmpty {
            let merchantUID = (resolvedMerchantUID?.isEmpty == false ? resolvedMerchantUID : request?.order.orderCode) ?? ""
            guard !merchantUID.isEmpty else {
                onComplete?(.failure("결제 응답에서 주문번호를 확인하지 못했습니다."))
                return
            }
            onComplete?(.success(impUID: impUID, merchantUID: merchantUID))
            return
        }

        if let errorMessage = response.error_msg, !errorMessage.isEmpty {
            onComplete?(.failure(errorMessage))
        } else {
            onComplete?(.cancelled)
        }
    }
}

//
//  HomeModelURLResolutionTests.swift
//  LSLP-iOSTests
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Testing
@testable import LSLP_iOS

struct HomeModelURLResolutionTests {

    @Test
    func bannerImageURLAddsV1PrefixForDataPath() {
        let banner = MainBanner(
            name: "Event",
            imageURL: "/data/banners/main.png",
            payload: BannerPayload(type: "web", value: "/events/1")
        )

        #expect(banner.resolvedImageURL?.absoluteString == "http://pickup.sesac.kr:42678/v1/data/banners/main.png")
    }

    @Test
    func bannerPayloadURLPreservesRelativePath() {
        let banner = MainBanner(
            name: "Event",
            imageURL: "/data/banners/main.png",
            payload: BannerPayload(type: "web", value: "/events/1")
        )

        #expect(banner.resolvedPayloadURL?.absoluteString == "http://pickup.sesac.kr:42678/events/1")
    }

    @Test
    func storeImageURLAddsV1PrefixForDataPath() throws {
        let store = try JSONDecoder().decode(StoreSummary.self, from: Data(
            """
            {
              "store_id": "store-1",
              "category": "coffee",
              "name": "Store",
              "close": "21:00",
              "store_image_urls": ["/data/stores/store-1.png"],
              "is_picchelin": false,
              "is_pick": false,
              "pick_count": 3,
              "hashTags": [],
              "total_rating": 4.5,
              "total_order_count": 10,
              "total_review_count": 2,
              "geolocation": {
                "longitude": 127.0,
                "latitude": 37.0
              },
              "distance": 120.0
            }
            """.utf8
        ))

        #expect(store.primaryImageURL?.absoluteString == "http://pickup.sesac.kr:42678/v1/data/stores/store-1.png")
    }

    @Test
    func urlResolverKeepsExistingV1PathUntouched() {
        let url = APIURLResolver.resolve(path: "/v1/data/stores/store-1.png")

        #expect(url?.absoluteString == "http://pickup.sesac.kr:42678/v1/data/stores/store-1.png")
    }
}

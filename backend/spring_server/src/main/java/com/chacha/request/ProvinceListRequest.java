package com.chacha.request;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.Setter;

@Schema(description = "국가별 광역시·도 목록 조회 요청")
@Getter
@Setter
public class ProvinceListRequest {

    @Schema(
        description = "국가 코드(ISO 3166-1 alpha-2)",
        example = "KR",
        required = true
    )
    private String countryCode = "KR";
}

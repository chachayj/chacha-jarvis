package com.chacha.request;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.Setter;

@Schema(description = "도/광역시별 구(區) 목록 조회 요청")
@Getter
@Setter
public class DistrictsRequest {

    @Schema(description = "광역시·도 코드", example = "KR-SEOUL", required = true)
    private String provinceCode;
}

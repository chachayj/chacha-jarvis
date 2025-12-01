package com.chacha.response;

import com.chacha.dto.ProvinceDto;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.util.List;

@Schema(description = "광역시·도 목록 응답")
@Data
public class ProvinceListResponse {

    @Schema(description = "총 광역시·도 개수", example = "17")
    private int total;

    @Schema(description = "광역시·도 리스트")
    private List<ProvinceDto> provinces;
}

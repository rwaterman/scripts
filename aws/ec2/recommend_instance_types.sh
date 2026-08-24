#!/usr/bin/env bash
# Recommend the five cheapest current-generation EC2 instance types for a given
# architecture, memory size, and vCPU count. Prices are on-demand Linux, shared
# tenancy, in the active AWS region.
#
# Requires the AWS CLI and jq (brew install jq).
set -euo pipefail

usage() {
  echo "Usage: $0 [x86|arm] [memory-gib] [vcpus]" >&2
  echo "Any argument left out is prompted for." >&2
  exit 1
}

normalize_architecture() {
  case "$(tr '[:upper:]' '[:lower:]' <<<"$1")" in
    x86 | x86_64 | amd64 | intel | amd) echo "x86_64" ;;
    arm | arm64 | aarch64 | graviton) echo "arm64" ;;
    *)
      echo "Unknown architecture: $1 (expected x86 or arm)" >&2
      exit 1
      ;;
  esac
}

require_positive_integer() {
  if ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
    echo "$1 must be a positive integer, received: $2" >&2
    exit 1
  fi
}

[[ $# -gt 3 ]] && usage

architecture_input="${1:-}"
memory_gib="${2:-}"
vcpus="${3:-}"

if [[ -z "$architecture_input" ]]; then
  read -r -p "Architecture [x86/arm] (default x86): " architecture_input
  architecture_input="${architecture_input:-x86}"
fi
if [[ -z "$memory_gib" ]]; then
  read -r -p "Memory in GiB (default 8): " memory_gib
  memory_gib="${memory_gib:-8}"
fi
if [[ -z "$vcpus" ]]; then
  read -r -p "vCPUs (default 4): " vcpus
  vcpus="${vcpus:-4}"
fi

architecture="$(normalize_architecture "$architecture_input")"
require_positive_integer "Memory" "$memory_gib"
require_positive_integer "vCPUs" "$vcpus"

region="${AWS_REGION:-$(aws configure get region || true)}"
if [[ -z "$region" ]]; then
  echo "AWS region is not set. Export AWS_REGION or run 'aws configure'." >&2
  exit 1
fi

candidates="$(aws ec2 describe-instance-types \
  --region "$region" \
  --filters \
    "Name=processor-info.supported-architecture,Values=${architecture}" \
    "Name=vcpu-info.default-vcpus,Values=${vcpus}" \
    "Name=memory-info.size-in-mib,Values=$((memory_gib * 1024))" \
    "Name=current-generation,Values=true" \
  --query 'InstanceTypes[].{type:InstanceType,network:NetworkInfo.NetworkPerformance,burstable:BurstablePerformanceSupported,localDisk:InstanceStorageSupported}' \
  --output json)"

if [[ "$(jq 'length' <<<"$candidates")" -eq 0 ]]; then
  echo "No current-generation ${architecture} instance types with ${vcpus} vCPUs and ${memory_gib} GiB in ${region}." >&2
  exit 1
fi

# The Pricing API is only served from a few regions; us-east-1 carries every region's price list.
prices="$(aws pricing get-products \
  --region us-east-1 \
  --service-code AmazonEC2 \
  --filters \
    "Type=TERM_MATCH,Field=regionCode,Value=${region}" \
    "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
    "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
    "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
    "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
    "Type=TERM_MATCH,Field=vcpu,Value=${vcpus}" \
    "Type=TERM_MATCH,Field=memory,Value=${memory_gib} GiB" \
  --query 'PriceList' \
  --output json)"

echo
echo "Cheapest on-demand Linux ${architecture} instance types with ${vcpus} vCPUs and ${memory_gib} GiB in ${region}:"
echo
jq -r --argjson candidates "$candidates" '
  ($candidates | map({key: .type, value: .}) | from_entries) as $specs
  | map(fromjson)
  | map({
      type: .product.attributes.instanceType,
      processor: .product.attributes.physicalProcessor,
      hourly: (.terms.OnDemand[] | .priceDimensions[] | .pricePerUnit.USD | tonumber)
    })
  | map(select($specs[.type] != null and .hourly > 0))
  | sort_by(.hourly)
  | unique_by(.type)
  | sort_by(.hourly)
  | .[:5]
  | (["TYPE", "USD/HR", "USD/MONTH", "NETWORK", "BURSTABLE", "LOCAL_DISK", "PROCESSOR"] | @tsv),
    (.[] | [
      .type,
      (.hourly * 10000 | round / 10000),
      (.hourly * 730 * 100 | round / 100),
      $specs[.type].network,
      $specs[.type].burstable,
      $specs[.type].localDisk,
      .processor
    ] | @tsv)
' <<<"$prices" | column -t -s $'\t'
